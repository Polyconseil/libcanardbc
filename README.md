libcanardbc
===========

Overview
--------

libcanardbc is a partial fork of cantools.sourceforge.net from rev47 (SVN).
This fork has been made to remove dependencies on hdf5 and matio, and to
fix compilation issues on Mac OS X in libdbc.

Only the DBC parser/lexer and associated library has been kept from the
original project.

The original cantools project is licensed under GPLv3, this means you can't link
the libraries of this project with a proprietary tool. This choice has been made
on purpose by Andreas Heitmann and so this fork inherits of the license.


Installation
------------

You will only need to install:
- automake
- autoconf
- libtool
- flex
- bison
- json-glib-1.0 (on Debian/Ubuntu: libjson-glib-dev; on other OSes probably a
similar name)

and a C compiler (gcc or clang) to compile the library.

To install, just run the usual dance, `./configure && make install`. Run
`./autogen.sh` first to generate the `configure` script if required.


Tools
-----

The directory `tools` contains several tools related to libcanardbc:

- **dbc2json** converts a DBC file to a JSON file. It's up to you to adapt it to
  your needs. This program is linked to libcanardbc so it is licensed under
  GPLv3.

- **json2dbc.py** converts a JSON file to a DBC file. It is usually easier to
  write a JSON file by hand than a DBC one.

- **json2html** renders a JSON file (DBC) to an HTML page. This program is
  distributed under BSD 3-Clause license.

Another project named [caneton](https://github.com/Polyconseil/caneton) uses
the generated JSON file of DBC to decode CAN messages.

DBC format
----------

The syntax of signals in DBC file is:

```
<object> <name> : <start bit>|<length>@<endiannes ex. 0 for Motorola, 1 for Intel><signedness ex. + (unsigned) or - (signed)> (<factor>,<offset>) <range, ex. 0|360> "<unit>" <nodes>
```

JSON format
-----------

You can see an example of a valid JSON file [here](https://github.com/Polyconseil/caneton/blob/master/tests/dbc.json). Below is the description of the schema it uses:

```
{
    "filename": "<filename>.dbc (optional)",
    "version": "<dbc_version> (optional)",
    "attribute_definitions": {
        "<attribute_name>": {
            "0": "<enum_value_0>",
            "<n>": "<enum_value_<n>>"
        }
    }
    "messages": {
        "<can_id>": {
            "name": "<message_name>",
            "sender": "<sending_node>",
            "length": <message_length_in_bytes>,
            "has_multiplexor (optional) ": <true|false>,
            "attributes": {
                "<attribute_name_1>": "<attribute_value_1>",
                "<attribute_name_<n>>": "<attribute_value_<n>>"
            }
            "signals": {
                "signal_1": {
                    "bit_start": <signal_data_offset_in_message>,
                    "length": <signal_data_length_in_bits>,
                    "little_endian": <0|1>,
                    "signed": <0|1>,
                    "value_type": "<integer|float|double>",
                    "factor": <factor_applied_to_signal_numerical_value>,
                    "offset": <offset_applied_to_signal_numerical_value>,
                    "min": <min_applied_to_signal_numerical_value>,
                    "max": <max_applied_to_signal_numerical_value>,
                    "unit": "<signal_data_unit (optional)>",
                    "multiplexor (optional)": <does_the_signal_define_multiplex_ids>,
                    "multiplexing (optional)": <multiplex_id_in_which_the_signal_exists>,
                    "enums (optional)" : {
                        "<enum_0_value>": "<enum_0_name>",
                        "<enum_<n>_value>": "<enum_<n>_name>"
                    }
                },
                "
            }
        }
    }
}
```
