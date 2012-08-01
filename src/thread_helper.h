/*
 * thread_helper.h
 * 
 * Copyright 2012 Adam Stark <astark@astark-laptop>
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

#ifndef THREAD_HELPER_H
#define THREAD_HELPER_H 1

#include <glib.h>
#include <glib-object.h>
#include <gobject/gvaluecollector.h>

typedef struct _ThreadHelperData ThreadHelperData;
typedef         GThread            ThreadHelperThread;

GThread* thread_helper_thread_to_gthread (ThreadHelperThread* thread);
ThreadHelperThread* thread_helper_thread_new (const gchar  *name,
                                              GThreadFunc  func,
                                              gpointer       data,
                                              GDestroyNotify unref );
ThreadHelperThread* thread_helper_thread_try_new 
											 (const gchar  *name,
                                              GThreadFunc  func,
                                              gpointer       data,
                                              GDestroyNotify unref,
                                              GError        **error);
#endif
