#!/usr/bin/env python

VERSION = "0.1.0"
VERSION_MAJOR_MINOR =  ".".join(VERSION.split(".")[0:2])
APPNAME = "unifid-remote"

srcdir = '.'
blddir = '_build_'

def options(conf):
    conf.load('compiler_c')
    conf.load('vala')
    conf.load('gnu_dirs')

def configure(conf):
    conf.load('compiler_c')
    conf.load('vala')
    conf.load('gnu_dirs')
    
    conf.find_program('vala-dbus-binding-tool', var='VALA_DBUS_BINDING_TOOL')

    conf.check_cfg(package='glib-2.0', uselib_store='GLIB',
            atleast_version='2.32.0', mandatory=True, args='--cflags --libs')
    conf.check_cfg(package='dbus-1', uselib_store='DBUS',
            atleast_version='1.4.0', mandatory=True, args='--cflags --libs')
    conf.check_cfg(package='gobject-2.0', uselib_store='GOBJECT',
            atleast_version='2.14.0', mandatory=True, args='--cflags --libs')
    conf.check_cfg(package='gio-2.0', uselib_store='GIO',
            atleast_version='2.10.0', mandatory=True, args='--cflags --libs')

    conf.define('PACKAGE', APPNAME)
    conf.define('PACKAGE_NAME', APPNAME)
    conf.define('PACKAGE_STRING', APPNAME + '-' + VERSION)
    conf.define('PACKAGE_VERSION', APPNAME + '-' + VERSION)

    conf.define('VERSION', VERSION)
    conf.define('VERSION_MAJOR_MINOR', VERSION_MAJOR_MINOR)

def build(bld):
    bld.recurse('src')

