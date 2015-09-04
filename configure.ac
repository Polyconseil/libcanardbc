m4_define([libcanhardbc_version_major], [0])
m4_define([libcanhardbc_version_minor], [1])
m4_define([libcanhardbc_version_micro], [0])

m4_define([libcanhardbc_version],
    [libcanhardbc_version_major.libcanhardbc_version_minor.libcanhardbc_version_micro])

AC_PREREQ([2.63])
AC_INIT([libcanhardbc], [libcanhardbc_version])
AM_INIT_AUTOMAKE([
	check-news
	foreign
	1.11
	-Wall -Wno-portability
	silent-rules
	tar-pax
	subdir-objects
])
AC_CONFIG_MACRO_DIR([m4])

# Check for programs.
AC_PROG_CC
AC_PROG_LEX
AC_PROG_YACC
LT_INIT([disable-static win32-dll pic-only])

AC_CHECK_HEADERS([ \
	stdlib.h \
	string.h \
])
AC_CHECK_FUNCS([ \
	strdup \
	strtol \
	strtoul \
])
AC_FUNC_MALLOC
AC_FUNC_STRTOD

PKG_CHECK_MODULES(TESTS, [glib-2.0 >= 2.42 json-glib-1.0 >= 1.0.2])

AC_SEARCH_LIBS([lrint], [m], [], [
  AC_MSG_ERROR([Unable to find lrint() function])
])

AC_CONFIG_FILES([
	Makefile
	src/Makefile
	tools/Makefile
])
AC_OUTPUT
