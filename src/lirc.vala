/*
 * lirc.vala
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
 
 using GLib;

namespace Lirc {
	//Sinc lirc client is a pretty small library, I figured it would
	//probably be worth my time to totally rewrite it so I can make
	//use of some f the features of Vala.
	
    public class Context : Object
    {
		public UnixSocketAddress socket_address { get; private set; }
		public string prog { get; private set;}
		public bool verbose { get; private set;}
		// Save the current lircd interface.
		public Context (string prog, bool verbose=false, string socket_path="/var/run/lirc/lircd") 
		{
			this.prog    = prog;
			this.verbose = verbose;
			this.socket_address = new UnixSocketAddress( socket_path );
		}
	}

	public class Listener : Object
	{
		private SocketClient listener_socket;
		private Context con;
		private SocketConnection connection;
		
		public Listener(Context con, MainContext? loop_context = null) throws Error
		{
			
			this.con = con;
			this.listener_socket = new SocketClient ();
			this.listener_socket.family = SocketFamily.UNIX;
			
			this.connection = this.listener_socket.connect (this.con.socket_address) ;
			if (loop_context != null)
			{
				var socket_source_in = this.connection.socket.create_source (IOCondition.IN);
				socket_source_in.set_callback (this.listener_callback);
				socket_source_in.attach(loop_context);
				
				var socket_source_die = this.connection.socket.create_source (IOCondition.ERR + IOCondition.HUP);
				socket_source_die.set_callback (this.listener_dies);
				socket_source_die.attach(loop_context);			
			}
				
		}
		private bool listener_callback (Socket listener, IOCondition event) 
		{
			if (event == IOCondition.IN && !this.connection.is_closed())
			{
				var buffer = new uint8[2048]; //I can't imagine that anything would be longer than this.
				try
				{
					this.connection.input_stream.read(buffer);
				}
				catch (IOError err)
				{
					return listener_dies (listener, event);
				}
				if (this.con.verbose)
				{
					Main.debug ("%s", (string) buffer);
				}
				uint8[] interpreted_key_code_buffer = new uint8[2048];
				uint8[]  device_conf_buffer = new uint8[2048];
				uint64 raw_key_code;
				uint8  repetition_number;
				
				if (((string) buffer).scanf("%Lx %hhx %2047s %2047s\n", out raw_key_code, out repetition_number, interpreted_key_code_buffer, device_conf_buffer) < 4) 
				{
					Main.debug ("Error: unexpected pattern: %s: %s", this.con.prog, (string) buffer);
					return true;
				};
				
				string interpreted_key_code = (string) interpreted_key_code_buffer;
				string device_conf          = (string) device_conf_buffer;
				this.button (device_conf, interpreted_key_code, repetition_number);
			}
			else if (event == IOCondition.IN) 
			{
				return listener_dies (listener, event);
			}
			return true;
		}
		private bool listener_dies (Socket listener, IOCondition event)
		{
			if (this.con.verbose)
			{
				Main.debug ("%s\n",  "Communication with socket interupted. Closing now.");
			}
			this.died();
			return true;
		}
		public signal void button (string device_conf, string interpreted_key_code, uint8 repetition_number);
		public signal void died ();
		public void close ()
		{
			try
			{
				this.connection.socket.close();
			}
			catch (Error e)
			{	//do nothing.
			}
		}
	}
/*
0000000087ee8a06 00 KEY_NEXT macmini.conf
*/
}
