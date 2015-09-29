#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright © 2015 Polyconseil SAS
# SPDX-License-Identifier: BSD-3-Clause
#
# Interpret CAN DLC (payload) to extract the values of the signals.
# Requires a DBC file.
#

import json
import argparse


def args_cleanup(args):
    # Check and cleanup message ID (minium 0x1)
    if len(args.id) > 2 and args.id[:2] == '0x':
        # It's an hexadecimal number
        can_id = int(args.id, 16)
    else:
        can_id = int(args.id)

    # Check and convert frame data to be a string of hexadecimal numbers without the 0x prefix
    if len(args.data) < 4:
        print("The CAN data is too short '%s'." % args.data)
        return

    if args.data[:2] != '0x':
        print("The CAN data '%s' is not prefixed by 0x." % args.data)
        return

    is_multiple_of_two = (len(args.data) % 2) == 0
    if not is_multiple_of_two:
        print("The CAN data is not a multiple of two '%s'." % args.data)
        return

    try:
        # Check hexadecimal
        int(args.data, 16)
        # Remove 0x
        data = args.data[2:]
        # Compute length in bytes
        data_length = len(data) // 2
    except ValueError:
        print("Invalid data argument '%s'." % args.data)
        return

    # Load file as JSON file
    try:
        dbc_json = json.loads(args.dbcfile.read())
    except ValueError:
        print("Unable to load the DBC file '%s' as JSON." % args.dbcfile)
        return

    return {
        'can_id': can_id, 'can_data': data,
        'can_data_length': data_length, 'dbc_json': dbc_json
    }


def frame_decode(can_id, can_data, can_data_length, dbc_json):
    """Decode a CAN frame.

    Arguments:
    - CAN ID, integer
    - CAN data, string of hexadecimal numbers
    - CAN data length, the length of CAN data in bytes."""
    if 'messages' not in dbc_json:
        print("Invalid DBC file (no messages entry).")
        return

    try:
        message = dbc_json['messages'][str(can_id)]
        print("Message %s (%d)" % (message['name'], can_id))
    except KeyError:
        print("Message ID %d (0x%x) not found in JSON file." % (can_id, can_id))
        return

    # Inverse byte order for DBC 0xAABBCCDD to 0xDDCCBBAA
    can_data_inverted = ''
    for i in range(can_data_length):
        index = (can_data_length - i - 1) * 2
        can_data_inverted += can_data[index:index + 2]

    print("CAN data: %s" % can_data)
    print("CAN data inverted: %s" % can_data_inverted)
    can_data_binary_length = can_data_length * 8
    # 0n to fit in n characters width with 0 padding
    can_data_binary = format(eval('0x' + can_data_inverted), '0%db' % can_data_binary_length)
    print("CAN data binary (%d): %s" % (can_data_binary_length, can_data_binary))

    signals = sorted(message['signals'].items(), key=lambda t: int(t[1]['bit_start']))
    for signal_name, signal_data in signals:
        signal_bit_start = signal_data['bit_start']
        if signal_bit_start >= can_data_binary_length:
            raise ValueError("Bit start %d of signal %s is too high" % (
                signal_bit_start, signal_name))

        # Compute bit position from bit start (DBC format is awful...)
        data_bit_start = (signal_bit_start // 8) * 8 + (7 - (signal_bit_start % 8))
        signal_length = signal_data['length']
        # 010010 bit start 4 and length 3: 100
        s_value = can_data_binary[data_bit_start:data_bit_start + signal_length]
        # If BE first bit is LSB
        if not s_value:
            print("Error the CAN frame data provided is too short")
            return

        is_little_endian = int(signal_data['little_endian'])
        if is_little_endian:
            # In Intel format (little-endian), bit_start is the position of the
            # Least Significant Bit so it needs to be reversed
            s_value = s_value[::-1]

        signal_factor = signal_data.get('factor', 1)
        signal_offset = signal_data.get('offset', 0)
        value = int(s_value, 2) * signal_factor + signal_offset
        unit = signal_data.get('unit', '')
        print("""Signal {name} - ({length}@{bit_start} {endianness})x{factor}+{offset} = {value} {unit}""".format(
            name=signal_name, bit_start=signal_bit_start, length=signal_length,
            factor=signal_factor, offset=signal_offset,
            endianness="LSB" if is_little_endian else "MSB",
            value=value, unit=unit))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Analyze of CAN frame with DBC information.")
    parser.add_argument(
        'dbcfile', type=argparse.FileType('r'),
        help="DBC file converted in JSON format to use for decoding.")
    parser.add_argument('id', type=str, help="ID of the message on the CAN bus (eg. 0x5BB or 1467)")
    parser.add_argument('data', type=str, help="data in hexadecimal (eg. 0x1112131415161718)")
    args = parser.parse_args()

    cleanup = args_cleanup(args)
    if cleanup:
        frame_decode(**cleanup)
