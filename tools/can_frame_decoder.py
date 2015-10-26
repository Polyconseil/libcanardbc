#!/usr/bin/env python3
#
# Copyright © 2015 Polyconseil SAS
# SPDX-License-Identifier: BSD-3-Clause
#
# Interpret CAN DLC (payload) to extract the values of the signals.
# Requires a DBC file.
#

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
        raise ValueError("The CAN data is too short '%s'." % args.data)

    # Test the first bytes are the 0x prefix
    if args.data[:2] != '0x':
        raise ValueError("The CAN data '%s' is not prefixed by 0x." % args.data)

    # Remove the 0x prefix
    data = args.data[2:]
    data_length = len(data)

    is_multiple_of_two = (data_length % 2) == 0
    if not is_multiple_of_two:
        raise ValueError("The CAN data is not a multiple of two '%s'." % args.data)

    data_byte_length = data_length // 2
    if data_byte_length > CAN_DATA_BYTE_LENGTH:
        raise ValueError("The CAN data length is too large (%d > %d)" % (
            data_byte_length, CAN_DATA_BYTE_LENGTH))

    try:
        # Check hexadecimal
        int(data, 16)
    except ValueError:
        raise ValueError("Invalid data argument '%s'." % args.data)

    # Load file as JSON file
    try:
        dbc_json = json.loads(args.dbcfile.read())
    except ValueError:
        raise ValueError("Unable to load the DBC file '%s' as JSON." % args.dbcfile)

    return {
        'can_id': can_id, 'can_data': data, 'dbc_json': dbc_json
    }


def swap_bytes(data):
    # Inverse byte order for DBC 0xAABBCCDD to 0xDDCCBBAA
    data_swapped = ''
    for i in range(len(data), 0, -8):
        data_swapped += data[i - 8:i]
    return data_swapped


def signal_decode(signal_name, signal_data,
    can_data_binary_msb, can_data_binary_lsb, can_data_binary_length):
    signal = {
        'name': signal_name,
        'length': signal_data['length']
    }
    bit_start = signal_data['bit_start']
    is_little_endian = int(signal_data['little_endian'])
    signal['endianess'] = 'LSB' if is_little_endian else 'MSB'

    if is_little_endian:
        can_data_binary = can_data_binary_lsb
    else:
        can_data_binary = can_data_binary_msb

    if bit_start >= can_data_binary_length:
        raise ValueError("Bit start %d of signal %s is too high" % (
            bit_start, signal_name))

    if is_little_endian:
        # In Intel format (little-endian), bit_start is the position of the
        # Least Significant Bit so it needs to be byte swapped
        signal['bit_end'] = can_data_binary_length - bit_start
        signal['bit_start'] = signal['bit_end'] - signal['length']
    else:
        # Motorola. Weird thing of the DBC format
        signal['bit_start'] = (bit_start // 8) * 8 + (7 - (bit_start % 8))
        signal['bit_end'] = signal['bit_start'] + signal['length']

    s_value = can_data_binary[signal['bit_start']:signal['bit_end']]

    signal['factor'] = signal_data.get('factor', 1)
    signal['offset'] = signal_data.get('offset', 0)
    signal['value'] = int(s_value, 2) * signal['factor'] + signal['offset']
    signal['unit'] = signal_data.get('unit', '')

    return signal


def signal_print(signal):
    print("""Signal {name} - ({length}@{bit_start} {endianness})x{factor}+{offset} = {value} {unit}""".format(
        **signal))


def message_get_multiplexed(signals, can_data_binary_msb, can_data_binary_lsb, can_data_binary_length):
    multiplexed = None
    for signal_name, signal_data in signals.items():
        if signal_data.get('multiplexor', False):
            signal = signal_decode(signal_name, signal_data, can_data_binary_msb, can_data_binary_lsb,
                can_data_binary_length)
            multiplexed = signal['value']
            break

    return multiplexed

def frame_decode(can_id, can_data, dbc_json, is_json_output=False):
    """Decode a CAN frame.

    Args:
        can_id: int, CAN ID
        can_data: str, hexadecimal numbers
        dbc_json: file, DBC file parsed with JSON reader
        is_json_output: bool, print output in JSON or not

    Raises:
        ValueError: raised when the data aren't in the expected format
    """
    if 'messages' not in dbc_json:
        raise ValueError("Invalid DBC file (no messages entry).")

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
        raise ValueError("Message ID %d (0x%x) not found in JSON file." % (can_id, can_id))

    # Intel (2 characters for a byte)
    can_data_binary_length = len(can_data) * 4

    # Motorola requires prefilled data
    # 0n to fit in n characters width with 0 padding
    can_data_binary_msb = format(eval('0x' + can_data), '0%db' % can_data_binary_length)
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

    if message.get('has_multiplexor', False):
        multiplexed = message_get_multiplexed(
            message['signals'], can_data_binary_msb, can_data_binary_lsb,
            can_data_binary_length)
    else:
        multiplexed = None

    signals = sorted(message['signals'].items(), key=lambda t: int(t[1]['bit_start']))
    for signal_name, signal_data in signals:
        # Decode signal only when no multiplexor or the signal is associated to the
        # current mode or the signal is not multiplexed
        if multiplexed is None or multiplexed == signal_data.get('multiplexed', multiplexed):
            signal = signal_decode(
                signal_name, signal_data, can_data_binary_msb, can_data_binary_lsb,
                can_data_binary_length)

            if is_json_output:
                output['signals'].append(signal)
            else:
                signal_print(signal)

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
