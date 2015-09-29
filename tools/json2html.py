#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright © 2015 Polyconseil SAS
# SPDX-License-Identifier: BSD-3-Clause
#
# Display JSON file of a DBC in HTML
# Requires a DBC file.
#
# Tested with Python 3.4
#

import argparse
import datetime
import json


def print_html_signals(signals):
    print("<table class='table table-border table-hover'>")

    # Header
    print("<tr>")
    headers = ('Signal name', 'Start bit', 'Length', 'Endianness', 'Factor',
               'Offset', 'Range', 'Enums')
    for header in headers:
        print("<th>%s</th>" % header)
    print("</tr>")

    # Content
    signals = sorted(signals.items(), key=lambda t: int(t[1]['bit_start']))
    for signal_name, signal in signals:
        print("<tr>")
        print("<td>{name}</td>".format(name=signal_name))
        if 'enums' in signal:
            enums = u"<br>".join(u"%s: %s" % (value, name) for value, name in sorted(signal['enums'].items()))
        else:
            enums = ''

        print(u"<td>%s</td>" * 7 % (
            signal["bit_start"], signal["length"], "LSB" if signal["little_endian"] else "MSB",
            signal["factor"], signal["offset"], "%s to %s" % (signal["min"], signal["max"]), enums))
        print("</tr>")
    print("</table>")


def print_html(args):
    # Load file as JSON file
    try:
        dbc_json = json.loads(args.dbcfile.read())
    except ValueError:
        print("Unable to load the DBC file '%s' as JSON." % args.dbcfile)
        return

    print("<!doctype html>")
    print("<html>")
    print("<meta><link rel='stylesheet' href='https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css'>")
    print("<body>")
    print("<div class='container'>")
    print("<div class='jumbotron'>")
    print("<h2>%s</h2>" % dbc_json['filename'])
    print("<p class='lead'>%s</p>" % datetime.datetime.now())
    print("</div>")

    print("<div class='row'>")

    # Fetch attribute definitions for future use
    attribute_definitions = dbc_json.get('attribute_definitions')

    # Sort by message ID
    message_id_list = sorted(dbc_json['messages'].keys(), key=int)
    for message_id in message_id_list:
        # Message header
        message = dbc_json['messages'][message_id]
        print("<h3>%s (%s)</h3>" % (message['name'], hex(int(message_id))))
        print("<p>Length: %s - Transmitter: %s - Decimal: %s </p>" % (
            message['length'], message['sender'], message_id))

        for attribute_name, attribute_value in message.get('attributes', {}).items():
            # Display the value of the attribute or its enum when available
            attribute_definition = attribute_definitions.get(attribute_name)
            if attribute_definition:
                attribute_value = attribute_definition.get(attribute_value, attribute_value)
            print("<p>%s: %s</p>" % (attribute_name, attribute_value))

        # Signals
        if 'signals' in message:
            print_html_signals(message['signals'])

    print("</div>")
    print("</div>")
    print("</body>")
    print("</html>")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Display JSON file of a DBC in HTML.")
    parser.add_argument(
        'dbcfile', type=argparse.FileType('r'),
        help="DBC in JSON format to use for decoding")
    args = parser.parse_args()
    print_html(args)
