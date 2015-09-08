#!/usr/bin/env python
# Copyright (c) Polyconseil SAS. All rights reserved.
# -*- coding: utf-8 -*-

import json
import argparse

def args_cleanup(args):
    # Check and convert frame data to be a string of hexadecimal numbers without the 0x prefix
    if len(args.data) < 4:
        print("The CAN frame is too short '%s'." % args.data)
        return

    is_multiple_of_two = (len(args.data) % 2) == 0
    if not is_multiple_of_two:
        print("The CAN frame is not a multiple of two '%s'." % args.data)
        return

    try:
        hex(eval(args.data))
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
        'can_id': args.id, 'can_data': data,
        'can_data_length': data_length, 'dbc_json': dbc_json
    }


def frame_decode(can_id, can_data, can_data_length, dbc_json):
    """Decode a CAN frame.

    Arguments:
    - CAN ID, integer
    - CAN data, string of hexadecimal numbers
    - CAN data length, the length of CAN data in bytes."""
    try:
        message = dbc_json['messages'].get(str(can_id))
        print("Message %s" % message['name'])
    except KeyError:
        print("Invalid DBC file (no messages entry)")

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

    for signal_name, signal_data in message['signals'].items():
        bit_start = signal_data['bitstart']
        # Compute bit position from bit start (DBC format is awful...)
        bit_pos = (bit_start // 8) * 8 + (7 - (bit_start % 8))
        bit_length = signal_data['length']
        print("Bit start %d (%d), computed position is %d" % (bit_start, bit_length, bit_pos))
        # DBC addresses seem to be Big-Endian
        # 010010 bit start 4 and length 3: 100
        s_value = can_data_binary[bit_pos:bit_pos + bit_length]
        if not s_value:
            print("Error the CAN frame data provided is too short")
            return

        value = int(s_value, 2) * signal_data.get('scale', 1)
        unit = signal_data.get('unit', '')
        print("Signal '{name}': {value} {unit}".format(name=signal_name, value=value, unit=unit))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Analyze of CAN frame with DBC information.")
    parser.add_argument('id', type=int, help="ID of the equipment on the CAN bus")
    parser.add_argument('data', type=str, help="data in hexadecimal (eg. 0xA234B)")
    parser.add_argument(
        'dbcfile', type=argparse.FileType('r'),
        help="DBC in JSON format to use for decoding")
    args = parser.parse_args()

    cleanup = args_cleanup(args)
    if cleanup:
        frame_decode(**cleanup)
