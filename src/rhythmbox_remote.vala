/* -*- Mode: Vala; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * rhythmbox_remote.vala
 * Copyright (C) 2012 Adam and Monica Stark <adstark1982@yahoo.com>
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name ``Adam and Monica Stark'' nor the name of any other
 *    contributor may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 * 
 * dbus-introspect IS PROVIDED BY Adam and Monica Stark ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL Adam and Monica Stark OR ANY OTHER CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

using GLib;


public class Main : GLib.Object 
{
	static List<Lircable> queue_to_check;
	static LircDispatcher dispatcher;

	static void touch(GLib.Object object) {
		return; 
	}

	static int main (string[] args) {	
		if (!Thread.supported()) {
        	error ("Cannot run without threads.\n");
        	return 1;
    	}
    	var loop                       = new MainLoop();
    	var startup                    = new IdleSource();
    	var listener_may_exit_self     = new Mutex();
    	var listener                   = new LircListener(loop.get_context(),listener_may_exit_self);
    	
    	startup.set_callback(() => 
    		{
    			stdout.printf("Starting main loop.\n");
		    	dispatcher                 = new LircDispatcher(listener);
    			ThreadHelper.Thread<bool> listener_thread = 
    				new ThreadHelper.Thread<bool>("listener",listener.lirc_main_loop);
    
    			var exiter = new Exiter(listener_thread.to_gthread(), loop,listener_may_exit_self);
 
    			int[] responses = { Posix.SIGINT, Posix.SIGTERM, Posix.SIGHUP} ;
    			foreach (var signal_code in responses) 
    			{
    				var signal_handler = new Unix.SignalSource(signal_code);
    				signal_handler.set_callback( exiter.on_exit_delegate ) ;
    				signal_handler.attach(loop.get_context());
    			}
    			
    			stdout.printf("Processing signals.\n");
    			return false;
    		});
    	
    	
    	
    	startup.attach(loop.get_context());
    	
    	loop.run();
    	
    	touch(listener);
    	return 0;
	}
	static void prepare_interfaces() {
		stdout.printf("Preparing interfaces\n");
	}
	static void handle_message(RemoteCommand command, LircDispatcher e) {
		stdout.printf("Handling message %s\n", command.to_string());
	}
}

public class Exiter : GLib.Object
{
    private unowned Thread<bool> listener_thread;
    private MainLoop loop;
    private unowned Mutex listener_may_exit_self;
    public Exiter(Thread<bool> listener_thread, MainLoop loop, Mutex listener_may_exit_self) 
    { 
   		this.listener_thread = listener_thread;
   		this.loop            = loop;
   		this.listener_may_exit_self =
   							   listener_may_exit_self;
   	}
   	public bool on_exit_delegate()	
   	{
   		// If the listener thread takes the lock, then it must exit.
   		if (listener_may_exit_self.trylock()) 
	    	listener_thread.exit(true);
    	
    	loop.quit(); 
    	return false;
    }
} 
   

// The main listener thread for LIRC
public class LircListener : GLib.Object
{
	private unowned MainContext context;
	private unowned Mutex listener_may_exit_self;
	// | signalled after a new button is pressed.
	public signal void lirc_button_raw(RemoteCommand command, int index);
	// | causes the thread to enter its main loop wherein
	// it listens for messages along the
	public bool lirc_main_loop() {
		stdout.printf("Entering main LIRC Loop.\n");
		
		this.lirc_button_raw(RemoteCommand.PLAYPAUSE, 0); 
		
		stdout.printf("Exiting main LIRC Loop.\n");
		
		// End the loop.
		this.listener_may_exit_self.lock() ;
		return false;
	}
	public LircListener(MainContext context, Mutex listener_may_exit_self) {
		context                     = context;
		this.listener_may_exit_self = listener_may_exit_self;
		stdout.printf("Creating listener.\n");
	}
}

public class LircDispatcher : GLib.Object
{
	public  int timeout              { get; set ; default = 20; }
	public  int length_of_long_press { get; set ; default = 1000; }
	private int time_at_start_of_cycle                = 0;
	private RemoteCommand current_command             = 0;
	private int           next_expected_interval_code = 0;
	private int           length_of_current_press     = 0;
	private LircListener listener ;
	public LircDispatcher( LircListener listener ) 
	{
		base();
		this.listener = listener ;
		stdout.printf("Creating dispatcher\n");
		listener.lirc_button_raw.connect((e, command, index) => 
			{
				stdout.printf("Received raw message %s %i\n",command.to_string(), index);
				bool send_previous = true;
			});
	}
	private void send_old_message() {
	}
	public signal void prepare_interfaces() ;
	public signal void send_button(RemoteCommand command) ; 
	public void to_here() {
		return;
	}
}

public enum RemoteCommand
{
	PLAYPAUSE,
	SEEKF,
	SEEKB,
	SKIPF,
	SKIPB,
	VOLU,
	VOLD,
	MENU,
	STOP
}

/*
 *  A Lircable object is one that can handle lirc commands.
 */
public interface Lircable : GLib.Object 
{
	/* Returns a negative number indicating the Lircable object in question's
	 * priority to run a specified command.
	 *
	 * A response of 0 means that the command cannot be run.
	 * Any other result means that the command can be run. unified_remote will examine
	 * all results before deciding which one to use, and the highest
	 * priority only will be run.
	 */
	public abstract int get_priority_adjustment(RemoteCommand command);
	/* Handle the specified command.
	 */
	public abstract void handle_lirc_signal(RemoteCommand command) throws DBusError, IOError;
	/* Ensure that the program referenced is quiet, for the benefit of other
	 * programs.
	 */
	public abstract void make_quiet() throws DBusError, IOError;
}

/* priority  P S S   M S
 * of        L E K V E T
 * command   A E I O N O
 *           Y K P L U P
 *
 * rhythmbox (or mpris flavored player) 
 *   playing 2*1 2 2 - 1?
 *   raised  1 - 1 1 - -
 *   lowered - - - 1 - -
 * totem            
 *   playing 2*1 2 2 2 1
 *   raised  1 - 1 1 - -
 *   lowered - - - 1 - -
 * menusys
 *   raised  3 2 3 3 3 2
 *   lowered - - - 2 1
 */
