bin_PROGRAMS = dbc2json
dist_bin_SCRIPTS = dbcjson2html.py dbc2html.sh

AM_CFLAGS = \
	-DLIBEXECDIR=\""$(libexecdir)"\" \
	-I${top_srcdir}/src \
	-I${top_builddir}/src \
	$(TESTS_CFLAGS)

AM_LDFLAGS = ${TESTS_LIBS} \
	$(top_builddir)/src/libcandbc.la
