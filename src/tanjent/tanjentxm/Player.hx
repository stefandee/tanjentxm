/* Licensed under The MIT License (MIT), see license.txt*/
package tanjent.tanjentxm;

import flash.media.Sound;
import flash.events.SampleDataEvent;
import flash.media.SoundChannel;
import flash.media.SoundTransform;
import flash.utils.ByteArray;

/** <p>
 * This is a helper class to load and play {@link XMModule} modules.
 * This class is meant to be used with the OpenFL library.
 * </p>
 * <p>
 * Note that this Player will use a SampleDataEvent for its mixing. Also it has been found that
 * starting, stopping and re-starting AS3-streams is a bit buggy. Current solution is to fire the
 * stream once and then always provide some data. To stop the stream entirely (to save on CPU)
 * call the halt() function then create a new Player to play again.
 * </p>
 * <p>
 * The player object references modules by an auto generated module reference number. This number is
 * returned from the loadXM() and addXM() functions and later passed on to the play() method to tell
 * which module should be played next.  
 * </p>
 * <p>
 * Example usage:
 * </p>
 * <p>
 * <code>
 * var p:Player = new Player(44100, Player.INTERPOLATION_MODE_NONE);<br>
 * var awesome:Int = p.loadXM(Assets.getBytes("assets/awesome.xm"), 0);<br>
 * p.play(awesome, true, true, 0, 0);<br>
 * ... do stuff, and when needed:<br>
 * p.pause();<br>
 * p.resume();<br>
 * ... then do more stuff, and when done:<br>
 * p.halt();<br>
 * </code>
 * </p>
 * @author Jonas Murman */ 
class Player
{
	
	private var modules:Array<XMModule>;
	private var currentModule:XMModule;
	private var nextModule:XMModule;
	
	/// this is a silent, non playing module
	private var dummyModule:XMModule;
	
	private var sampleRate:Int;
	private var tickMixer:TickMixer;
	
	public static inline var INTERPOLATION_MODE_NONE:Int = 0;
	public static inline var INTERPOLATION_MODE_LINEAR:Int = 1;
	public static inline var INTERPOLATION_MODE_CUBIC:Int = 2;
	private var interpolationMode:Int;	

	private var amplitude:Float;
	private var sound:Sound;
	private var soundChannel:SoundChannel;	
	
	/// Buffer size of the streaming audio generation, i.e. the amount of stereo pairs pushed in each SampleDataEvent.
	/// Should range between 2048 ... 8192. A smaller buffer size means higher CPU but less latency.
	/// 2048 samples has a tendency to stutter in the Flash player.
	/// Latency at a sample rate of 44100: 8192 = 0.18s = 185msec; 4096 = 0.09s = 93msec; 2048 = 0.04s = 46 msec	
	/// Call frequency at 44100: 8192 = 5.3 Hz; 4096 = 10.7 Hz; 2048 = 21.5 Hz
	private static inline var BUFFER_SIZE:Int = 8192;
	
	private var samplesWritten:Int;
	private var samplesLeftInBuffer:Int;
	private var bufferPosition:Int;
	private var tickSamples:Int;
	
	private var halted:Bool;
	public function isHalted():Bool
	{
		return halted;
	}
	
	private var fading:Bool;
	private var fadeFactor:Float;	
	private var fadeFactorDelta:Float;
	private static inline var FADE_STATUS_FADE_OUT:Int = 0;
	private static inline var FADE_STATUS_FADE_IN:Int = 1;	
	private static inline var FADE_STATUS_FADE_DONE:Int = 2;	
	private var fadeStatus:Int;	
	private var fadeSamplesLeftToProcess:Int;
	private var fadeInSamplesToProcess:Int;
	
	public static inline var JUMP_STYLE_JUMP:Int = 0;
	public static inline var JUMP_STYLE_KEY_OFF_NOTES:Int = 1;
	public static inline var JUMP_STYLE_KEY_CUT_NOTES:Int = 2;

	/**
	 * Creates a new Player. The player will not mix sound until the play() function is called.
	 * @param sampleRate the sample rate to use (usually 44100 samples/second). This parameter is obsolete, we're always using Sound.sampleRate internally
	 * @param interpolationMode the interpolation mode to use (Player.INTERPOLATION_MODE...)
	 */	
	public function new(sampleRate:Int = 44100, interpolationMode:Int = Player.INTERPOLATION_MODE_NONE) 
	{
		this.modules = new Array<XMModule>();
		this.currentModule = null;
		this.nextModule = null;
		this.dummyModule = null;

		// create the sound
		this.sound = new Sound();
		this.sound.addEventListener(SampleDataEvent.SAMPLE_DATA, this.playerSampleDataEvent);
		this.soundChannel = null;		
		
		//
		// create the tickmixer and set interpolation mode and amplitude
		//
		
		// Sound.sampleRate may differ depeding on the audio devices available (it can be 44100, 48000 or about any other value),
		// so we are using it instead of the user supplied sampleRate. It might be possible to make TickMixer use a different sample rate
		// than the Sound, although some refactoring might be required (and not sure it's entirely necessary)
		this.setSampleRate(this.sound.sampleRate);
		this.setInterpolationMode(interpolationMode);	
		this.setAmplitude(1.0);
						
		// init buffer handling
		this.samplesWritten = 0;
		this.samplesLeftInBuffer = 0;
		this.bufferPosition = 0;
		this.tickSamples = 0;
		
		this.halted = false;
		
		// init the fading
		this.fading = false;
		this.fadeFactor = 1.0;
		this.fadeFactorDelta = 0.0;
		this.fadeStatus = Player.FADE_STATUS_FADE_DONE;
		this.fadeSamplesLeftToProcess = 0;
		this.fadeInSamplesToProcess = 0;
		
		// make sure modules are non-null
		this.validateAndPlayModules(false, false);
	}
	
	/// The standard SampleDataEvent
	private function playerSampleDataEvent(event:SampleDataEvent)
	{
		if (this.halted == true) return;
		
		// do the slower event with fading support?
		if (this.fading == true) {
			this.playerFadingSampleDataEvent(event);
			return;
		}
				
		// write as much of the current tick buffer as possible to the sample data buffer
		this.samplesWritten = 0;
		if (this.samplesLeftInBuffer > 0) {					
			for (s in 0 ... this.samplesLeftInBuffer) {				
				event.data.writeFloat(FixedPoint.FP_TO_FLOAT(this.tickMixer.leftSamples[this.bufferPosition]));
				event.data.writeFloat(FixedPoint.FP_TO_FLOAT(this.tickMixer.rightSamples[this.bufferPosition]));
				this.samplesWritten++;
				this.bufferPosition++;
				this.samplesLeftInBuffer--;
				if (this.samplesWritten >= Player.BUFFER_SIZE) return;
			}
		}
		
		while (true)
		{
			// get next tick (this is fast)
			this.currentModule.advanceByOneTick();
			
			// mix to the tick buffer (this is slow)
			switch(this.interpolationMode)
			{
				case INTERPOLATION_MODE_NONE:
					this.tickSamples = this.tickMixer.renderTickNoInterpolation(this.currentModule);
				case INTERPOLATION_MODE_LINEAR:
					this.tickSamples = this.tickMixer.renderTickLinearInterpolation(this.currentModule);
				case INTERPOLATION_MODE_CUBIC:
					this.tickSamples = this.tickMixer.renderTickCubicInterpolation(this.currentModule);
			}
			
			// fill sample data buffer with samples from the tick buffer
			this.bufferPosition = 0;
			this.samplesLeftInBuffer = this.tickSamples;
			for (s in 0 ... this.tickSamples) {
				event.data.writeFloat(FixedPoint.FP_TO_FLOAT(this.tickMixer.leftSamples[this.bufferPosition]));
				event.data.writeFloat(FixedPoint.FP_TO_FLOAT(this.tickMixer.rightSamples[this.bufferPosition]));
				this.samplesWritten++;
				this.bufferPosition++;
				this.samplesLeftInBuffer--;												
				if (this.samplesWritten >= Player.BUFFER_SIZE) break;
			}		
			
			// filled the entire sample buffer?
			if (this.samplesWritten >= Player.BUFFER_SIZE) return;			
		}		
	}
	
	/// An extended (slower) SampleDataEvent that supports fading between two modules.
	private function playerFadingSampleDataEvent(event:SampleDataEvent)
	{
		// write as much of the current tick buffer as possible to the sample data buffer
		this.samplesWritten = 0;
		if (this.samplesLeftInBuffer > 0) {	
			for (s in 0 ... this.samplesLeftInBuffer) {	
				// fade
				this.fadeFactor += this.fadeFactorDelta;
				this.fadeSamplesLeftToProcess--;
				if (this.fadeSamplesLeftToProcess <= 0 && this.fadeStatus != Player.FADE_STATUS_FADE_DONE) {
					// fading in? then we are done
					if (this.fadeStatus == Player.FADE_STATUS_FADE_IN)
					{
						// fade is done
						this.fading = false;
						this.fadeStatus = Player.FADE_STATUS_FADE_DONE;
						this.fadeFactor = 1.0;
						this.fadeFactorDelta = 0.0;
					}
					
					// fading out? init fade-in instead
					if (this.fadeStatus == Player.FADE_STATUS_FADE_OUT) {
						// swap module
						this.currentModule = this.nextModule;
						
						// set up fade delta
						if (this.fadeInSamplesToProcess <= 0)
						{
							// fade is already done
							this.fading = false;
							this.fadeStatus = Player.FADE_STATUS_FADE_DONE;
							this.fadeFactor = 1.0;
							this.fadeFactorDelta = 0.0;
						} else {
							// move to fade in
							this.fadeStatus = Player.FADE_STATUS_FADE_IN;
							this.currentModule = this.nextModule;
							this.fadeFactor = 0.0;
							this.fadeSamplesLeftToProcess = this.fadeInSamplesToProcess;
							this.fadeFactorDelta = 1.0 / this.fadeSamplesLeftToProcess;
						}					
						
						// break and retrieve new samples from the next module
						break;					
					}
				}
				
				event.data.writeFloat(FixedPoint.FP_TO_FLOAT(this.tickMixer.leftSamples[this.bufferPosition]) * this.fadeFactor);
				event.data.writeFloat(FixedPoint.FP_TO_FLOAT(this.tickMixer.rightSamples[this.bufferPosition])* this.fadeFactor);
				this.samplesWritten++;
				this.bufferPosition++;
				this.samplesLeftInBuffer--;
				if (this.samplesWritten >= Player.BUFFER_SIZE) return;
			}
		}
		
		while(true) {
			// get next tick (this is fast)
			this.currentModule.advanceByOneTick();
			
			// mix to the tick buffer (this is slow)
			switch(this.interpolationMode)
			{
				case INTERPOLATION_MODE_NONE:
					this.tickSamples = this.tickMixer.renderTickNoInterpolation(this.currentModule);
				case INTERPOLATION_MODE_LINEAR:
					this.tickSamples = this.tickMixer.renderTickLinearInterpolation(this.currentModule);
				case INTERPOLATION_MODE_CUBIC:
					this.tickSamples = this.tickMixer.renderTickCubicInterpolation(this.currentModule);
			}
			
			// fill sample data buffer with samples from the tick buffer
			this.bufferPosition = 0;
			this.samplesLeftInBuffer = this.tickSamples;
			for (s in 0 ... this.tickSamples) {
				// fade
				this.fadeFactor += this.fadeFactorDelta;
				this.fadeSamplesLeftToProcess--;
				if (this.fadeSamplesLeftToProcess <= 0 && this.fadeStatus != Player.FADE_STATUS_FADE_DONE) {
					// fading in? then we are done
					if (this.fadeStatus == Player.FADE_STATUS_FADE_IN)
					{
						// fade is done
						this.fading = false;
						this.fadeStatus = Player.FADE_STATUS_FADE_DONE;
						this.fadeFactor = 1.0;
						this.fadeFactorDelta = 0.0;
					}
					
					// fading out? init fade-in instead
					if (this.fadeStatus == Player.FADE_STATUS_FADE_OUT) {
						// swap module
						this.currentModule = this.nextModule;
						
						// set up fade delta
						if (this.fadeInSamplesToProcess <= 0)
						{
							// fade is already done
							this.fading = false;
							this.fadeStatus = Player.FADE_STATUS_FADE_DONE;
							this.fadeFactor = 1.0;
							this.fadeFactorDelta = 0.0;
						} else {
							// move to fade in
							this.fadeStatus = Player.FADE_STATUS_FADE_IN;
							this.currentModule = this.nextModule;
							this.fadeFactor = 0.0;
							this.fadeSamplesLeftToProcess = this.fadeInSamplesToProcess;
							this.fadeFactorDelta = 1.0 / this.fadeSamplesLeftToProcess;
						}

						// break and retrieve new samples from the next module
						break;						
					}						
				}
												
				event.data.writeFloat(FixedPoint.FP_TO_FLOAT(this.tickMixer.leftSamples[this.bufferPosition]) * this.fadeFactor);
				event.data.writeFloat(FixedPoint.FP_TO_FLOAT(this.tickMixer.rightSamples[this.bufferPosition]) * this.fadeFactor);
				this.samplesWritten++;
				this.bufferPosition++;
				this.samplesLeftInBuffer--;
				if (this.samplesWritten >= Player.BUFFER_SIZE) break;
			}
			
			// filled the entire sample buffer?
			if (this.samplesWritten >= Player.BUFFER_SIZE) return;		
		}
	}
	
	/**
	 * Adds an already loaded {@link XMModule} to the internal module collection and returns
	 * a module reference number to be passed to to the play() method.
	 * The same module can have several reference numbers, but they will all share the same underlying
	 * base module. This means they will share patterns, channels and currently playing sample states.
	 * @param module the module to add
	 * @return the module reference number or -1 on error
	 */	
	public function addXM(module:XMModule):Int
	{
		if (module == null) return -1;
		
		for (i in 0 ... this.modules.length)
		{
			if (this.modules[i] == null)
			{
				this.modules[i] = module;
				return i;
			}
			if (this.modules[i] == module) 
			{
				return i;
			}
		}
						
		return (this.modules.push(module) - 1); 		
	}

	/**
	 * Removes an already loaded {@link XMModule} in the internal module collection.
	 * If the module is playing it will also be stopped.
	 * @param moduleNumber the module reference number
	 */	
	public function removeXM(moduleNumber:Int)
	{
		if (moduleNumber < 0) return;		
		if (moduleNumber >= this.modules.length) return;
		
		if (this.modules[moduleNumber] == this.currentModule) {
			this.stop();
		}
		if (this.modules[moduleNumber] == this.nextModule) {
			this.nextModule = this.dummyModule;
		}
				
		this.modules[moduleNumber] = null;
	}	
		
	/**
	 * Loads and creates a {@link XMModule} from a binary data representation of a FT2 XM-file. Adds the module
	 * to an internal module collection. Use the returned module reference number to play this module when calling the play() method.
	 * @param data the binary data of an XM file 
	 * @param mixFactor the per channel amplitude factor to use when rendering samples (set to -1 or 0 to auto calculate)
	 * <ul> 
	 * <li>Pass -1 to auto calculate the mixing factor as 1/sqrt(numberOfChannels)
	 * <li>Pass 0 to auto calculate the mixing factor as 1/numberOfChannels
	 * <li>Pass >0 for anything else, i.e. 2.0 will play the module twice as loud (and will probably distort!)
	 * </ul> 	 
	 * @return the module reference number or -1 on error
	 */	
	public function loadXM(data:ByteArray, mixFactor:Float):Int
	{
		var newXMModule:XMModule = new XMModule(this.sampleRate, mixFactor);
		if (newXMModule.loadXM(data) == false)
		{
			return -1;
		}
		
		for (i in 0 ... this.modules.length)
		{
			if (this.modules[i] == null)
			{
				this.modules[i] = newXMModule;
				return i;
			}
		}
						
		return (this.modules.push(newXMModule) - 1);
	}	
	
	/**
	 * Starts the SampleDataEvent (if not already running) and plays the {@link XMModule} associated with the given module reference number.
	 * Note that as soon as this is playing it will consume CPU/Battery until the halt() method is called.
	 * @param moduleNumber the reference number of the module to play (use -1 to play silence)
	 * @param restartModule true = restart module, false = play from last position
	 * @param loopOnEnd true = loop from the restart position (usually the beginning), false = stop on last row of the last pattern (beware of hanging notes!)
	 * @param fadeOutCurrentSeconds the number of seconds to fade out the current playing song before fading in the next
	 * @param fadeInNextSeconds  the number of seconds to fade in the next song 
	 */	
	public function play(moduleNumber:Int, restartModule:Bool = true, loopOnEnd:Bool=true, fadeOutCurrentSeconds:Float=0.25, fadeInNextSeconds:Float=0.25)
	{
		if (moduleNumber < 0 || moduleNumber >= this.modules.length)
		{
			this.nextModule = null;
		} else {
			this.nextModule = modules[moduleNumber];
		}

		// unnecessary swap?
		if (this.currentModule == this.nextModule) {
			this.validateAndPlayModules(restartModule, loopOnEnd);
			return;
		}
		
		this.fading = false;		
		
		// swap immediately?
		if (fadeOutCurrentSeconds <= 0) {
			this.currentModule = this.nextModule;
			this.fadeStatus = Player.FADE_STATUS_FADE_OUT;
			this.fadeSamplesLeftToProcess = 0;	
		} else {
			this.fading = true;
			this.fadeStatus = Player.FADE_STATUS_FADE_OUT;
			this.fadeSamplesLeftToProcess = Std.int(fadeOutCurrentSeconds * this.sampleRate);
			this.fadeFactorDelta = -this.fadeFactor / this.fadeSamplesLeftToProcess;
		}
		
		if (fadeInNextSeconds <= 0) { 
			this.fadeInSamplesToProcess = 0;			
		} else {
			this.fading = true;
			this.fadeInSamplesToProcess = Std.int(fadeInNextSeconds * this.sampleRate);
		}
		
		this.validateAndPlayModules(restartModule, loopOnEnd);
		
		// start streaming playback
		if (this.soundChannel == null)
		{				
			this.soundChannel = this.sound.play();
			this.soundChannel.soundTransform = new SoundTransform(this.amplitude);
		}	
		
		// reset fading
		if (this.fading == false) {
			this.fadeFactor = 1.0;
			this.fadeFactorDelta = 0;
		}
	}
	
	private function validateAndPlayModules(restart:Bool, loop:Bool)
	{
		if (this.currentModule == null) this.currentModule = this.dummyModule;
		if (this.nextModule == null) this.nextModule = this.dummyModule;
		
		if (this.nextModule != this.dummyModule) {
			this.nextModule.play(loop);
			if (restart == true) this.nextModule.restart();
		}
	}
	
	/**
	 * Returns the associated {@link XMModule} for a given module reference number.
	 * @param moduleNumber the module reference number
	 * @return the associated {@link XMModule} or null on error
	 */
	public function getModule(moduleNumber:Int):XMModule
	{
		if (moduleNumber < 0) return null;
		if (moduleNumber >= this.modules.length) return null;		
		return modules[moduleNumber];
	}
	
	public function getSampleRate():Int
	{
		return this.sampleRate;
	}
	
	/**
	 * Sets the sample rate. Normally this should be 44100 since that is what the SampleDataEvent expects.
	 * @param	sampleRate sample rate to use
	 */
	public function setSampleRate(sampleRate:Int)
	{
		this.sampleRate = sampleRate;
		if (this.sampleRate <= 0) this.sampleRate = 44100;		
		this.tickMixer = new TickMixer(this.sampleRate);
		
		// update modules
		for (module in this.modules)
		{
			if (module != null)
			{
				module.sampleRate = this.sampleRate;
			}
		}

		if (this.dummyModule == null) {
			this.dummyModule = new XMModule(this.sampleRate, 1.0);
		} else {
			this.dummyModule.sampleRate = this.sampleRate;
		}
	}
	
	public function getInterpolationMode():Int
	{
		return this.interpolationMode;
	}
	
	/**
	 * Sets the interpolation mode. On mobile use INTERPOLATION_MODE_NONE for everything. 
	 * On Desktop PC use INTERPOLATION_MODE_CUBIC, even if INTERPOLATION_MODE_LINEAR is usually good enough.
	 * @param	interpolationMode the interpolation mode to use
	 */
	public function setInterpolationMode(interpolationMode:Int)
	{
		this.interpolationMode = INTERPOLATION_MODE_NONE;
		switch(interpolationMode)
		{
			case INTERPOLATION_MODE_LINEAR:
				this.interpolationMode = INTERPOLATION_MODE_LINEAR;
			case INTERPOLATION_MODE_CUBIC:
				this.interpolationMode = INTERPOLATION_MODE_CUBIC;
		}
	}
	
	public function getAmplitude():Float
	{
		return this.amplitude;
	}	
	
	/** Sets the amplitude of the stream.     
	 * @param amplitude the amplitude to use (0 = mute player, < 1 decrease volume, > 1 increase volume)
	 */
	public function setAmplitude(amplitude:Float)
	{
		if (amplitude < 0) amplitude = 0;						
		this.amplitude = amplitude;
		
		if (this.soundChannel != null) {
			this.soundChannel.soundTransform = new SoundTransform(this.amplitude);
		}
	}
	
		
	/** Fades out the playback then stops and goes into a low CPU-stream mode (streaming silence). */
	public function stop(fadeOutSeconds:Float = 0.25)
	{
		this.play(-1, false, false, fadeOutSeconds, 0);
	}
	
	/** Halts the player and stops the SampleDataEvent from firing.
	 * To restart the music stream after calling this a new Player must be created.*/
	public function halt()
	{
		this.halted = true;
		if (this.sound != null)
		{
			this.sound.removeEventListener(SampleDataEvent.SAMPLE_DATA, this.playerSampleDataEvent);			
		}
		if (this.soundChannel != null)
		{
			this.soundChannel.soundTransform = new SoundTransform(0);
			this.soundChannel.stop();
			this.soundChannel = null;			
		}
	}
	
	/** Jumps to the specifed row and pattern index in the pattern order, handling notes according to one of the Player.JUMP_STYLE_... jump styles.
	 * @param	moduleNumber	the module reference number
	 * @param	patternIndex the pattern order index to jump to (-1 to jump in the current pattern)
	 * @param	patternRow the row to jump to (-1 jump to same row as currently playing)
	 * @param	jumpStyle the jump style to use;  Player.JUMP_STYLE_JUMP = jump immediately - beware of hanging notes, Player.JUMP_STYLE_KEY_OFF_NOTES = insert a key-off note in every channel to allow playing notes to fade out, Player.JUMP_STYLE_KEY_CUT_NOTES = stop channel from playing by cutting notes off, may click
	 */
	public function jump(moduleNumber:Int, patternIndex:Int, patternRow:Int, jumpStyle:Int=Player.JUMP_STYLE_JUMP)
	{
		if (patternIndex < 0 && patternRow < 0) return;
		
		var m:XMModule = this.getModule(moduleNumber);
		
		if (m != null) {		
			if (patternIndex < 0) patternIndex = m.patternIndex;
			if (patternRow < 0) patternRow = m.patternRow;

			if (jumpStyle == Player.JUMP_STYLE_KEY_OFF_NOTES) {							
				for (c in 0 ... m.numberOfChannels) {
					m.keyOff(c);
				}
			} else if (jumpStyle == Player.JUMP_STYLE_KEY_CUT_NOTES) {
				for (c in 0 ... m.numberOfChannels) {
					m.keyCut(c);
				}		
			}						
					
			// jump at the next tick
			m.jump(patternIndex, patternRow);
		}		
	}
	

	/** Queues the provided note data to the referenced module. The new note data will override the original pattern data when read at the next row. 
	 * This is read only once and the original pattern data is not modified.
	 * @param	moduleNumber	the module reference number
	 * @param	channel	the channel to use (-1 = auto-select a channel, uses random voice stealing if all channels are playing)
	 * @param	note	the note to play (-1 = do not replace when next row is read)
	 * @param	instrument	the instrument to use (-1 = do not replace when next row is read)
	 * @param	volume	the volume column data to use (-1 = do not replace when next row is read)
	 * @param	effectType	the effect type to use (-1 = do not replace when next row is read)
	 * @param	effectParameter	the effect parameter data to use (-1 = do not replace when next row is read)
	 * @return	the channel number of the note event (-1 = invalid module or invalid pattern)
	 */
	public function queueNoteData(moduleNumber:Int, channel:Int=-1, note:Int=-1, instrument:Int=-1, volume:Int=-1, effectType:Int=-1, effectParameter:Int=-1):Int
	{
		var m:XMModule = this.getModule(moduleNumber);
		return this.queueNoteDataM(m, channel, note, instrument, volume, effectType, effectParameter);
	}

	private function queueNoteDataM(m:XMModule, channel:Int, note:Int, instrument:Int, volume:Int, effectType:Int, effectParameter:Int):Int
	{
		if (m == null) return -1;
							
		// play a note?
		if (note != -1 && note != XMModule.NOTE_KEYOFF) {							
			if (channel < 0) {
				// find a "free" channel
				
				// any non-playing channels?
				for (i in 0 ... m.channels.length) {					
					var c:XMChannel = m.channels[i];									
					if (c.playing == false && m.queuedNotes[i] == null) {
						channel = i;
						break;
					}
				}

				if (channel < 0) {				
					// no, all channels are playing, try to find one with the lowest volume											
					// start with a random one, to prevent the same channel from being selected all the time
					var minFPChannel:Int = Std.int(Math.random() * m.channels.length);
					var minFP:Int = m.channels[minFPChannel].volumeFP;
					for (i in 0 ... m.channels.length) {					
						var c:XMChannel = m.channels[i];
						if (c.volumeFP < minFP) {
							minFP = c.volumeFP;
							minFPChannel = i;
						}
					}					
					channel = minFPChannel;
				}
			}
		} else {
			// no new "note" incoming, this event can be a KEY_OFF, some volume row data, or some other effect/column data
			if (channel < 0) {
				// get a random channel
				channel = Std.int(Math.random() * m.channels.length);				
			}							
		}
		
		if (channel >= m.channels.length) channel = m.channels.length - 1;
				
		// enqueue for playback at the next first tick
		m.queueNote(channel, note, instrument, volume, effectType, effectParameter);
		
		return channel;
	}
}