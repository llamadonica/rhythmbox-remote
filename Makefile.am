## Process this file with automake to produce Makefile.in
## Created by Anjuta

SUBDIRS = src 

rhythmbox_remotedocdir = ${prefix}/doc/rhythmbox_remote
rhythmbox_remotedoc_DATA = \
	README\
	COPYING\
	AUTHORS\
	ChangeLog\
	INSTALL\
	NEWS


EXTRA_DIST = $(rhythmbox_remotedoc_DATA)


# Remove doc directory on uninstall
uninstall-local:
	-rm -r $(rhythmbox_remotedocdir)
