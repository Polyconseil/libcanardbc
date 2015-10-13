#!/usr/bin/env python3
#
# Copyright © 2015 Polyconseil SAS
# SPDX-License-Identifier: BSD-3-Clause
#
# Interpret CAN DLC (payload) to extract the values of the signals.
# Requires a DBC file.
#

import sys
import json
import argparse

CAN_DATA_BYTE_LENGTH = 8


def args_cleanup(args):
    # Check and cleanup message ID (minium 0x1)
    if len(args.id) > 2 and args.id[:2] == '0x':
        # It's an hexadecimal number
        can_id = int(args.id, 16)
    else:
        can_id = int(args.id)

    # Check the message data

    # Check the length of the data before removing the 0x prefix
    if len(args.data) < 4:
        print("The CAN data is too short '%s'." % args.data, file=sys.stderr)
        return

    # Test the first bytes are the 0x prefix
    if args.data[:2] != '0x':
        print("The CAN data '%s' is not prefixed by 0x." % args.data, file=sys.stderr)
        return

    # Remove the 0x prefix
    data = args.data[2:]
    data_length = len(data)

    is_multiple_of_two = (data_length % 2) == 0
    if not is_multiple_of_two:
        print("The CAN data is not a multiple of two '%s'." % args.data, file=sys.stderr)
        return

    data_byte_length = data_length // 2
    if data_byte_length > CAN_DATA_BYTE_LENGTH:
        print("The CAN data length is too large (%d > %d)" % (
            data_byte_length, CAN_DATA_BYTE_LENGTH), file=sys.stderr)
        return

    try:
        # Check hexadecimal
        int(data, 16)

        # The signal addresses are indicated in DBC file for CAN message of 64 bits so we add
        # missing bits at the beginning of the string.
        # data = '00' * (CAN_DATA_BYTE_LENGTH - data_byte_length) + data
    except ValueError:
        print("Invalid data argument '%s'." % args.data, file=sys.stderr)
        return

    # Load file as JSON file
    try:
        dbc_json = json.loads(args.dbcfile.read())
    except ValueError:
        print("Unable to load the DBC file '%s' as JSON." % args.dbcfile, file=sys.stderr)
        return

    return {
        'can_id': can_id, 'can_data': data, 'dbc_json': dbc_json
    }


def swap_bytes(data):
    # Inverse byte order for DBC 0xAABBCCDD to 0xDDCCBBAA
    # FIXME prefill or postfill?
    data_swapped = ''
    for i in range(len(data), 0, -8):
        data_swapped += data[i - 8:i]
    return data_swapped


def frame_decode(can_id, can_data, dbc_json, is_json_output=False):
    """Decode a CAN frame.

    Arguments:
    - can_id, CAN ID as integer
    - can_data, string of hexadecimal numbers
    - dbc_json, DBC file parsed with JSON reader
    - is_json_output, print output in JSON or not
    """
    if 'messages' not in dbc_json:
        print("Invalid DBC file (no messages entry).", file=sys.stderr)
        return

    if is_json_output:
        # Initialize the structure to output JSON
        output = {'signals': []}

    try:
        message = dbc_json['messages'][str(can_id)]
        if is_json_output:
            output['message'] = {'name': message['name'], 'id': can_id}
        else:
            print("Message %s (%d)" % (message['name'], can_id))
    except KeyError:
        print("Message ID %d (0x%x) not found in JSON file." % (can_id, can_id), file=sys.stderr)
        return

    # Intel (2 characters for a byte)
    can_data_binary_length_lsb = len(can_data) * 4

    # Motorola requires prefilled data
    can_data_binary_length_msb = len(can_data) * 4

    # 0n to fit in n characters width with 0 padding
    can_data_binary_msb = format(eval('0x' + can_data), '0%db' % can_data_binary_length_msb)
    # For Intel
    can_data_binary_lsb = swap_bytes(can_data_binary_msb)

    if is_json_output:
        output['data'] = {
            'original': can_data,
            'binary_msb': can_data_binary_msb,
            'binary_lsb': can_data_binary_lsb
        }
    else:
        print("CAN data: %s" % can_data)
        print("CAN data binary MSB: %s" % (can_data_binary_msb))
        print("CAN data binary LSB: %s" % (can_data_binary_lsb))

    signals = sorted(message['signals'].items(), key=lambda t: int(t[1]['bit_start']))
    for signal_name, signal_data in signals:
        signal_bit_start = signal_data['bit_start']
        is_little_endian = int(signal_data['little_endian'])

        if is_little_endian:
            can_data_binary = can_data_binary_lsb
            can_data_binary_length = can_data_binary_length_lsb
        else:
            can_data_binary = can_data_binary_msb
            can_data_binary_length = can_data_binary_length_msb

        if signal_bit_start >= can_data_binary_length:
            raise ValueError("Bit start %d of signal %s is too high" % (
                signal_bit_start, signal_name))

        signal_length = signal_data['length']
        if is_little_endian:
            # In Intel format (little-endian), bit_start is the position of the
            # Least Significant Bit so it needs to be byte swapped
            signal_bit_end = can_data_binary_length - signal_bit_start
            signal_bit_start = signal_bit_end - signal_length
        else:
            # Motorola. Weird thing of the DBC format
            signal_bit_start = (signal_bit_start // 8) * 8 + (7 - (signal_bit_start % 8))
            signal_bit_end = signal_bit_start + signal_length

        s_value = can_data_binary[signal_bit_start:signal_bit_end]
        # print("%s %d:%d => %d:%d = %s" % (
        #     signal_name,
        #     signal_data['bit_start'], signal_data['bit_start'] + signal_length,
        #     signal_bit_start, signal_bit_end, hex(int(s_value, 2))))

        signal_factor = signal_data.get('factor', 1)
        signal_offset = signal_data.get('offset', 0)
        value = int(s_value, 2) * signal_factor + signal_offset
        unit = signal_data.get('unit', '')
        if is_json_output:
            signal = {
                'name': signal_name,
                'bit_start': signal_bit_start,
                'length': signal_length,
                'factor': signal_factor,
                'offset': signal_offset,
                'endianness': 'LSB' if is_little_endian else 'MSB',
                'value': value, 'unit': unit
            }
            output['signals'].append(signal)
        else:
            print("""Signal {name} - ({length}@{bit_start} {endianness})x{factor}+{offset} = {value} {unit}""".format(
                name=signal_name, bit_start=signal_bit_start, length=signal_length,
                factor=signal_factor, offset=signal_offset,
                endianness="LSB" if is_little_endian else "MSB",
                value=value, unit=unit))

    if is_json_output:
        return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Analyze of CAN frame with DBC information.")
    parser.add_argument(
        'dbcfile', type=argparse.FileType('r'),
        help="DBC file converted in JSON format to use for decoding.")
    parser.add_argument('id', type=str, help="ID of the message on the CAN bus (eg. 0x5BB or 1467)")
    parser.add_argument('data', type=str, help="data in hexadecimal (eg. 0x1112131415161718)")
    parser.add_argument('--output', type=str, choices=['json', 'text'], default='text',
        help="Format of the output (JSON or text)")
    args = parser.parse_args()
    args.is_json_output = (args.output == 'json')

    cleanup = args_cleanup(args)
    if cleanup:
        frame_decode(
            can_id=cleanup['can_id'], can_data=cleanup['can_data'],
            dbc_json=cleanup['dbc_json'], is_json_output=args.is_json_output)
