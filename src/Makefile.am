## Process this file with automake to produce Makefile.in

## Created by Anjuta



AM_CPPFLAGS = \
	-DPACKAGE_LOCALE_DIR=\""$(localedir)"\" \
	-DPACKAGE_SRC_DIR=\""$(srcdir)"\" \
	-DPACKAGE_DATA_DIR=\""$(pkgdatadir)"\" \
	$(RHYTHMBOX_REMOTE_CFLAGS)

AM_CFLAGS =\
	 -Wall\
	 -g

bin_PROGRAMS = rhythmbox-remote

rhythmbox_remote_SOURCES = \
	rhythmbox_remote.vala config.vapi thread_helper.c lirc.vala org-freedesktop.vala org-mpris.vala

rhythmbox_remote_VALAFLAGS =  --pkg gio-2.0 \
        --pkg glib-2.0 \
        --pkg gobject-2.0  \
	--pkg libpulse \
        --pkg libpulse-mainloop-glib \
        --pkg gio-unix-2.0

rhythmbox_remote_LDFLAGS = \
	-Wl,--export-dynamic

rhythmbox_remote_LDADD = $(RHYTHMBOX_REMOTE_LIBS)

org-mpris.vala: interface/org.mpris.MediaPlayer2.rhythmbox.xml
	$(DBUS_BINDING_TOOL) --gdbus --api-path=$<
org-freedesktop.vala: interface/org.freedesktop.DBus.xml
	$(DBUS_BINDING_TOOL) --gdbus --api-path=$<
