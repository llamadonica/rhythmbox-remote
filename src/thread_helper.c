/*
 * thread_helper.c
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

#include "thread_helper.h"

struct _ThreadHelperData {
	GThreadFunc	func;
	gpointer		data;
	GDestroyNotify	finalizer;
};

static gpointer thread_helper_thread_lambda (ThreadHelperData* helper_func);

static gpointer thread_helper_thread_lambda (ThreadHelperData* helper_func) {
	gpointer result = NULL;
	result = (helper_func->func) (helper_func->data);
	(helper_func->finalizer == NULL) ? NULL : (helper_func->finalizer) (helper_func->data);
	/* Does ThreadHelperData need ref counting? In this case, I'm going to say no,
	 * because it's unclear under what circumstances it might have an increased reference,
	 * because it's not owned per se. It's RUNNING!
	 */
	g_slice_free (ThreadHelperData, helper_func);
	return result;
}
GThread* thread_helper_thread_to_gthread (ThreadHelperThread* thread) {
	return thread;
}
ThreadHelperThread* thread_helper_thread_new (const gchar  *name,
                                              GThreadFunc  func,
                                              gpointer       data,
                                              GDestroyNotify unref )
{
	ThreadHelperData* inner_data;
	
	inner_data = g_slice_new0 (ThreadHelperData);
	inner_data->func      = func;
	inner_data->data      = data;
	inner_data->finalizer = unref;
	return g_thread_new (name, (GThreadFunc) thread_helper_thread_lambda, inner_data);
}

ThreadHelperThread* thread_helper_thread_try_new (const gchar  *name,
                                              GThreadFunc  func,
                                              gpointer       data,
                                              GDestroyNotify unref,
                                              GError        **error)
{
	
	GThread* result = NULL;
	GError*   inner_error   = NULL;
	ThreadHelperData* inner_data;
	
	inner_data = g_slice_new (ThreadHelperData);
	inner_data->func      = func;
	inner_data->data      = data;
	inner_data->finalizer = unref;
	
	result = g_thread_try_new (name, (GThreadFunc) thread_helper_thread_lambda, inner_data, &inner_error);
	if (inner_error != NULL) {
		if (inner_error->domain == G_THREAD_ERROR) {
			g_propagate_error (error, inner_error);
	        (unref == NULL) ? NULL : (unref (data), NULL);
	        g_slice_free (ThreadHelperData, inner_data);
			return NULL;
		} else {
	        (unref == NULL) ? NULL : (unref (data), NULL);
	        g_slice_free (ThreadHelperData, inner_data);
	        
	        g_critical ("file %s: line %d: uncaught error: %s (%s, %d)", __FILE__, __LINE__, inner_error->message, g_quark_to_string (inner_error->domain), inner_error->code);
			g_clear_error (&inner_error);
			return NULL;
		}
	}
	return result;
}
