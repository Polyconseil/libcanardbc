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

You will only to install:
- automake
- autoconf
- libtool
- flex
- bison

and a C compiler (gcc or clang) to compile the library.

To install, just run the usual dance, `./configure && make install`. Run
`./autogen.sh` first to generate the `configure` script if required.


Tools
-----

The directory `tools` contains several tools related to libcanardbc:

- **dbc2json** converts a DBC file to a JSON file. It's up to you to adapt it to
  your needs. This program is linked to libcanardbc so it is licensed under
  GPLv3.

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
