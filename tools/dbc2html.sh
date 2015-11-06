#!/bin/sh
BASE="`basename $1 .dbc`"
dbc2json "$1" "$BASE.json" && dbcjson2html.py "$BASE.json" > "$BASE.html" && echo "HTML $BASE.html created."
