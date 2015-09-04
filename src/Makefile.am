EXTRA_DIST =
lib_LTLIBRARIES = libcandbc.la

LEX=@LEX@
YACC=@YACC@

DEFS = $(YYDEBUG)

# YACC: generate token defines for LEX
AM_YFLAGS = -d

AM_CPPFLAGS = -I{srcdir}

## Enable debugging of linker script parser
YYDEBUG = -DYYDEBUG=1

CLEANFILES = \
	candbc-parser.h \
	candbc-parser.c \
	candbc-lexer.c

candbc-parser.h candbc-parser.c: candbc-parser.y

libcandbc_la_SOURCES = \
    candbc-model.h \
    candbc-model.c \
    candbc-reader.c \
    candbc-parser.y \
    candbc-lexer.l
