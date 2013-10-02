dnl Process this file with autoconf to produce a configure script.
dnl Created by Anjuta application wizard.

AC_INIT(rhythmbox-remote, 0.6)

AC_CONFIG_HEADERS([config.h])

AM_INIT_AUTOMAKE([1.11])

AM_SILENT_RULES([yes])

AC_PROG_CC



dnl Check for vala
AM_PROG_VALAC([0.10.0])

AC_CHECK_PROG(DBUS_BINDING_TOOL_YES,vala-dbus-binding-tool,yes,no)
if test x"${DBUS_BINDING_TOOL_YES}" == x"yes" ; then
    AC_PATH_PROG(DBUS_BINDING_TOOL,vala-dbus-binding-tool)
else
    AC_MSG_ERROR([Please install vala-dbus-binding-tool.])
fi

PKG_CHECK_MODULES(RHYTHMBOX_REMOTE, libpulse
libpulse-mainloop-glib
gio-unix-2.0
[gtk+-3.0 gio-2.0 dbus-1 glib-2.0 gobject-2.0])


AC_OUTPUT([
Makefile
src/Makefile

])
