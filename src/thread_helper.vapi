/*
 * thread_helper.vapi
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

[CCode (cheader_filename = "thread_helper.h")]
namespace ThreadHelper {
#if GLIB_2_32
	[Compact]
	[CCode (ref_function = "g_thread_ref", unref_function = "g_thread_unref")]
	public class Thread<T> {
		[CCode (cname = "thread_helper_thread_new" )]
		public Thread (string? name, owned GLib.ThreadFunc<T> func);
		[CCode (cname = "thread_helper_thread_try_new" )]
		public Thread.try (string? name, owned GLib.ThreadFunc<T> func) throws GLib.Error;
		[CCode (cname = "thread_helper_thread_to_gthread " )]
		public GLib.Thread to_gthread() ;
	}
#endif
}
