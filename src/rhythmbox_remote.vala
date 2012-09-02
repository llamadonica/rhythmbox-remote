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

const int64  SEEK_AMOUNT  = 4000000;

public class Main : GLib.Object 
{
    static const bool   DEBUG        = false;
    public static const string PROGRAM_NAME = "universal-remote";
    [PrintfFormat]
	public static void debug(string format, ...) {
		if (Main.DEBUG) {
			var l      = va_list();
			var output = format.vprintf(l);
			stderr.printf("%s: %s",Main.PROGRAM_NAME,output);
		}
	}
	static int main (string[] args) {	
		
		var context = new Lirc.Context (PROGRAM_NAME, true);
		Lirc.Listener listener;
		SignalRouter  router;
		var loop     = new MainLoop();
		try
		{ 
			listener = new Lirc.Listener (context, loop.get_context());
			router   = new SignalRouter (loop.get_context());
		}
		catch (IOError e)
		{
			Main.debug("Error: %s\n", e.message);
			return 1;
		}
		
		listener.button.connect(router.handle_lirc_button);
		listener.died.connect(loop.quit);
		
		loop.run();
    	
    	return 0;
	}
}   

public delegate void Func ();

public class SignalRouter : Object
{
	const   int64                         ADJUSTMENT_INCREMENT = 12800;
	private org.mpris.MediaPlayer2Player? rhythmbox_remote = null; //null if not connected;
	private org.freedesktop.DBus          dbus_connection;
	private PulseAudio.Context            pulse_audio_context;
	private Button                        pending_press;
	private TimeoutSource?                timeout_source;
	private MainContext                   glib_context;  
	private PulseAudio.GLibMainLoop       pa_main_loop;
	private PulseAudio.MainLoopApi        pa_main_loop_api;   
	private int64                         adjustment;
		
	public SignalRouter(MainContext context) throws Error
	{	
		this.glib_context = context;
		this.dbus_connection  = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.DBus", "/org/freedesktop/DBus");
		if (this.dbus_connection == null)
		{
			error ("Could not connect to DBus");
		}
		
		this.pa_main_loop = new PulseAudio.GLibMainLoop (context);
		this.pa_main_loop_api = pa_main_loop.get_api();
		
		this.pulse_audio_context = new PulseAudio.Context (pa_main_loop_api, Main.PROGRAM_NAME);
		this.pulse_audio_context.set_state_callback ((con_inner) =>
			{
				PulseAudio.Context.State state = con_inner.get_state();
				Main.debug( "PulseAudio changed state to %s.\n", state.to_string());
				switch (state) {
					case PulseAudio.Context.State.READY: 
						Main.debug( "Reached ready signal.\n" );
						break;
					default: break;
				}
			});
		
		Main.debug ("%s\n", this.pulse_audio_context.get_state().to_string());
		
		if (this.dbus_connection.name_has_owner ("org.gnome.Rhythmbox3"))
		{
			this.rhythmbox_remote = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.Rhythmbox3", "/org/mpris/MediaPlayer2");
			Main.debug ("%s\n", "SignalRouter connected to org.gnome.Rhythmbox3");
		}
		
		this.dbus_connection.name_owner_changed.connect ((name, old_owner, new_owner) =>
			{
				if (name != "org.gnome.Rhythmbox3")
					return;
				if (new_owner != "")
				{
					this.rhythmbox_remote = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.Rhythmbox3", "/org/mpris/MediaPlayer2");
					Main.debug ("%s\n", "SignalRouter connected to org.gnome.Rhythmbox3");
					return;
				}
				if (old_owner != "" && new_owner == "")
				{
					this.rhythmbox_remote = null;
					Main.debug ("%s\n", "SignalRouter disconnected from org.gnome.Rhythmbox3");
					return;
				}
			});
		var delayed_pa_source = new IdleSource();
		delayed_pa_source.set_callback(() =>
			{ 
				Main.debug ("%s\n",this.pulse_audio_context .get_state().to_string());
				if (this.pulse_audio_context.get_state() == PulseAudio.Context.State.UNCONNECTED
					&& this.pulse_audio_context.connect() < 0)
				{	
					Main.debug ("Error while connecting to PulseAudio server.");
				}
				return false;
			});
		delayed_pa_source.attach(context);
	}
	
	private bool handle_pending ()
	{
		var this_press = this.pending_press;
		if (this.pending_press == Button.NONE)
			return false;
		this.pending_press = Button.NONE;
		handle_lirc_command (this_press);
		return false;
	}
	
	private void adjust_volume(PulseAudio.Context context_inner, PulseAudio.SinkInfo? sink_info, int eol) 
	{
		PulseAudio.CVolume cVolume;
		if (eol!=0) return;
		lock(this.adjustment) {
			if (this.adjustment > (int64) uint32.MAX) {
				this.adjustment = (int64) uint32.MAX;
			}
			if (this.adjustment < -((int64) uint32.MAX)) {
				this.adjustment = - (int64) uint32.MAX;
			}
			if (this.adjustment < 0) 
			{
				cVolume = sink_info.volume.dec ((uint32)(-this.adjustment));
			}
			else
			{
				cVolume = sink_info.volume.inc ((uint32) this.adjustment);
			}
			this.adjustment = 0;
		}
		
		if (cVolume.max() > PulseAudio.Volume.NORM)
		{
			cVolume = cVolume.dec (cVolume.max() - PulseAudio.Volume.NORM);
		}
		if (cVolume.min() < PulseAudio.Volume.MUTED)
		{
			cVolume = cVolume.inc (PulseAudio.Volume.MUTED - cVolume.min());
		}
							
		context_inner.set_sink_volume_by_index (sink_info.index, cVolume);							
	}
	
	private void handle_lirc_command (Button button)
	{
		
		Main.debug ("%s %s\n", "Received true signal:", button.to_string());
		int64 seek_amount = SEEK_AMOUNT;
		PulseAudio.Volume increment = 10;
		
		switch (button)
		{
			case Button.PLAY_PAUSE:
				if (this.rhythmbox_remote != null)
				{
					this.rhythmbox_remote.play_pause(); 
					// FIXME: This should do something reasonable if
					// nothing can be played.
				}
				break;
			case Button.STOP:
				if (this.rhythmbox_remote != null)
				{
					this.rhythmbox_remote.stop();
				}
				break;
			case Button.SEEK_F:
				if (this.rhythmbox_remote != null)
				{
					this.rhythmbox_remote.next() ;
				}
				break;
			case Button.SEEK_R:
				if (this.rhythmbox_remote != null)
				{
					this.rhythmbox_remote.previous() ;
				}
				break;
			case Button.SCAN_R:
				seek_amount = -seek_amount;
				if (this.rhythmbox_remote != null)
				{
					this.rhythmbox_remote.seek (seek_amount) ;
				}
				break;
			case Button.SCAN_F:
				if (this.rhythmbox_remote != null)
				{
					this.rhythmbox_remote.seek (seek_amount) ;
				}
				break;
			case Button.VOL_DOWN:
			case Button.VOL_DOWN_C:
				lock(this.adjustment) {
					this.adjustment -= this.ADJUSTMENT_INCREMENT;
				}
				Main.debug ("%s\n", this.pulse_audio_context.get_state().to_string());
				var op = this.pulse_audio_context.get_sink_info_list (this.adjust_volume);
				if (op == null)
				{
					Main.debug ("Couldn't increase volume.\n");
				}
				break;
			case Button.VOL_UP:
			case Button.VOL_UP_C:
				lock(this.adjustment) {
					this.adjustment += this.ADJUSTMENT_INCREMENT;
				}
				Main.debug ("%s\n", this.pulse_audio_context.get_state().to_string());
				var op = this.pulse_audio_context.get_sink_info_list (this.adjust_volume);
				if (op == null)
				{
					Main.debug ("Couldn't increase volume.\n");
				}
				break;
			default:
				break; //Nothing;
		}
	}

	public void handle_lirc_button (string device_conf, string interpreted_key_code, uint8 repetition_number) 
	{   /* Now the fun part:
		 * 
		 * When a user presses a button once, there has to be a little
		 * lag to determine whether the user pressed the button multiple
		 * times or just once.
		 * 
		 * The system emits about 8.7 button presses per second. 4 consecutive
		 * button presses in under 0.57 seconds is reasonable
		 * to believe that the user intended to hold the button.
		 * 
		 * So here's what happens:
		 * 	 When the user hits the button for the first time (repetition_number=0): 
		 *     any pending timeouts are cancelled and executed early.
		 *     a new timeout is created for 0.3 seconds in the future with the default action for one press.
		 *   When a user hits a button the 4th time (repetition_number=3):
		 *     the pending timeout is cancelled.
		 *     the action for repeated action is executed.
		 *   Thereafter, every 3 times (repetition_number % 3 = 0)
		 *     the action for repeated action is executed.
		 */
		if (repetition_number == 0 || repetition_number == 3)
		{
			if (this.timeout_source != null)
			{
				this.timeout_source.destroy();
			}
			if (repetition_number == 0)
			{
				if (this.pending_press != Button.NONE)
				{
					this.handle_pending();
				}
				
				this.timeout_source = new TimeoutSource (400);
				
				switch (interpreted_key_code) {
					case "KEY_VOLUMEDOWN":
						this.pending_press = Button.VOL_DOWN_C; break;
					case "KEY_VOLUMEUP":
						this.pending_press = Button.VOL_UP_C; break;
					case "KEY_NEXT":
						this.pending_press = Button.SEEK_F; break;
					case "KEY_PREVIOUS":
						this.pending_press = Button.SEEK_R; break;
					case "KEY_PLAYPAUSE":
						this.pending_press = Button.PLAY_PAUSE; break;
					case "KEY_MENU":
						handle_lirc_command (Button.MENU); return;
					default:
						return;
				}
				
				this.timeout_source.set_callback (this.handle_pending) ;
				this.timeout_source.attach (this.glib_context);
				return;
			}
			
			if (interpreted_key_code == "KEY_PLAYPAUSE")
			{	// This is only handled once, but at signal 3
				handle_lirc_command (Button.STOP); return;
			}
		}
		if ((repetition_number % 3) == 0)
		{
			switch (interpreted_key_code) {
				case "KEY_VOLUMEDOWN":
					handle_lirc_command (Button.VOL_DOWN); return;
				case "KEY_VOLUMEUP":
					handle_lirc_command (Button.VOL_UP); return;
				case "KEY_NEXT":
					handle_lirc_command (Button.SCAN_F); return;
				case "KEY_PREVIOUS":
					handle_lirc_command (Button.SCAN_R); return;
				default:
						return;
			}
		}
	}
}

enum Button 
{
	NONE,
	PLAY_PAUSE,
	STOP,
	VOL_DOWN,
	VOL_UP,
	VOL_DOWN_C,
	VOL_UP_C,
	MENU,
	SEEK_F,
	SEEK_R,
	SCAN_F,
	SCAN_R
}
