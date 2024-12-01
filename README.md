# TanjentXM

TanjentXM is a free and open source library to play FastTracker II (FT2) .XM-files for HaXe 3+ and OpenFL.

The current version works with Haxe 4.3.6 and OpenFL 9.4.0 and it was tested for the HTML5 platform. Other platforms supported by OpenFL may work as well, but they were not tested yet.

I have found this library in an old installation of Haxe 3. I meant to test it for tracker music when ported [Loose Cannon](https://www.pirongames.com/loose-cannon-physics/), [Knight&Witch](https://www.pirongames.com/knight-and-witch/) and [Laser Lab](https://www.pirongames.com/laser-lab/) from Flash to HTML5, but I've forgot about it and went with another XM library (my own Haxe port of FlodXM).

It seems that the site where this library originated has disappared and I couldn't track its creator, Jonas Murman. The library seems useful and stable, so I've decided to port it to Haxe 4 and since its license is MIT, released it.

If you're the author of this piece, thank you for coding it and please feel free to take over it :)

Find below install instructions as well as the original readme.

## Install&Usage

The Git project is setup as a Haxe library and may be installed with:

```console
haxelib git tanjentxm https://github.com/stefandee/tanjentxm.git
```

Of course, this repository may be cloned and a absolute/relative src dependency may be added to your project.

The project comes with an [example project](https://github.com/stefandee/tanjentxm/tree/main/examples/haxe/TanjentXM1_3). This may be run with:

```console
openfl test html5
```

## Version History

- 2015-08-11 (Version 1.3) 
  - New "interactive" functions:
	* Support for note row data insertion
	* Support for pattern order/row jumping							
  - Looping envelopes bugfix
  - Updated example with new songs and interactive controls for OpenFL 3.1.0+* and libgdx 1.6.4+
- 2014-08-20 (Version 1.2) 
  - Small fix and updated examples for OpenFL 2.0.1+** and libgdx 1.3.1+  
- 2014-05-12 (Version 1.1) 
  - Small fix and updated examples for OpenFL 1.4.0+ and libgdx 1.0+ |						 
- 2014-01-01 (Version 1.0)
  - First released version

*) As of now projects targetting OpenFL 3.1 must be compiled with the "-Dlegacy"
flag set to ON to support streaming audio events.

**) WARNING! OpenFL 2.0.1 has shipped with a BUG that totally cripples
dynamic sound generation! To fix this you must modify the
SampleDataEvent.hx file in:

... \openfl\2,0,1\backends\native\openfl\events\SampleDataEvent.hx

Make sure the class constructor looks like this (i.e. uncomment lines 20 and 21):
```haxe
	public function new (type:String, bubbles:Bool = false, cancelable:Bool = false) {	
		super (type, bubbles, cancelable);		
		data = new ByteArray ();
		data.bigEndian = false;
		position = 0.0;		
	}
```
						  
## Introduction
This is an XM-file playback library written in Java and the HaXe 3.0
language. 

My ambition has been to create a free, fast, portable and light-weight 
XM-file player that can be deployed and used on various devices 
including desktop, mobile phones and tablet devices.

Included in the library is: 

1) XM-file loader and parser (Files: XM*)
2) Mixing engine (Files: FixedPoint, TickMixer)
3) Playback engine (Files: Player)

The playback engine (3) is the only part of the library that requires
integration with a game library or another realtime media library. For
the HaXe version this is typically the OpenFL/Lime platform. For the
Java version this is typically libgdx.

Since (1) and (2) does not rely on any special libraries it should be
easy to port this library to other (game) libraries that support dynamic
(streaming) sound output, the only part that will need rewriting is (3).

## Example Playback code (HaXe)
To play XM-files loaded as ByteArray-assets in a OpenFL/HaXe project the
following code can be used as a starting point:

```haxe
	var myPlayer:Player = new Player();
	var moduleOne:Int = myPlayer.loadXM(Assets.getBytes("assets/moduleOne.xm"), 0);	
	var moduleTwo:Int = myPlayer.loadXM(Assets.getBytes("assets/moduleTwo.xm"), 0);	
	myPlayer.play(moduleOne);
```
	
To fade out the current playing song for 0.25 seconds and play a new 
song with a fade-in of 1 second you can call the play() function with 
the following parameters: 	

```haxe
	myPlayer.play(moduleTwo, true, true, 0.25, 1);
```	
	
The first boolean specifies if the module should restart when playback
starts. The second boolean specifies if the module should loop from
the beginning (or the specified restart pattern index) when it has
reached the end. 
	
To stop the player, call:
	
```haxe
	myPlayer.stop();
```
	
To completely halt the player and stop the SampleDataEvent from
firing (saves CPU/Battery) call:

```haxe
	myPlayer.halt();
```	
	
To re-start a halted player you have to create a new player and add the 
modules again: 
	
```haxe	
	var myNewPlayer:Player = new Player();
	moduleOne = myNewPlayer.addXMModule(myPlayer.getModule(moduleOne));
	moduleTwo = myNewPlayer.addXMModule(myPlayer.getModule(moduleTwo));
	myNewPlayer.play(moduleOne);
```	

Please take a look at the provided examples in the examples folder.

## Design
This library has been designed to do one thing only, and that is to
make it easy to play .xm files!

The XM-file format has been chosen mainly because it has a good mix of 
musical expression/capabilities and reasonable performance tradeoffs: 

1) Support for 2 to 32 stereo channels
2) Support for 8-bit and 16-bit audio
3) Samples can have bidirectional loops
4) Support for instruments with vibrato, volume and panning envelopes
5) Patterns have both volume column and effect column
6) Determinable voice allocation (1 channel = 1 voice = 1 sample)
7) Lack of DSP-heavy per sample processing (i.e. no filters)

From the above list it is obvious that XM-files can reproduce a wide
range of different sounds. Songs can range from simple chip tunes
(< 20 kB) to massive multi-channel songs (> several MBs).

The software mixer has been designed using a Fixed Point-technique.
This means that it treats a certain number of bits of an integer as a 
decimal. This gives a very good performance when mixing samples on 
mobile devices. 

Tests have shown that a floating point version of the library has given 
about 1.5x - 2x slower performance in VM environments (such as the Flash 
player) and on Android (4+) devices, i.e. CPU usage has increased from 
4% to ~8% for certain modules (HaXe version).

The library also supports three kinds of interpolation modes when
pitch shifting samples:

1) No Interpolation (Nearest Neighbour)
2) Linear Interpolation
3) Cubic Interpolation

Use (1) on mobile phones to save as much CPU as possible and to be able 
to play 32-channel XM-files. The downside to (1) is some audible 
aliasing (a high pitched ringing) when pitching sounds - but it is also
very fast. Both (2) and (3) provided give less aliasing and can be used
on mobile of the channel count is low (< 8 channels) but they are of
course slower. Use (3) for the "best" quality this library offers.
Cubic interpolation will usually be used on powerful and stationary
devices such as desktops, or when doing off-line processing. 

To provide a sample rate of 96000 Hz or a cubic interpolation mode,
pass these parameters when creating the player object:

```haxe
	... = new Player(96000, Player.INTERPOLATION_MODE_CUBIC);
```
	
Since many platform assumes the standard 44100 samples/second sample
rate, this is used as the default sample rate.

##Interactive Music Support
In version 1.3+ I have added basic support for "interactive" playback.
This mean that it is possible to insert arbitrary note/row data during
playback as well as support for pattern and row jumping. Two new functions
are responsible for this functionality:

```haxe
	jump(moduleNumber:Int, patternIndex:Int, patternRow:Int, jumpStyle:Int=Player.JUMP_STYLE_JUMP)
```
	
	and:

```hax3	
	queueNoteData(moduleNumber:Int, channel:Int=-1, note:Int=-1, instrument:Int=-1, volume:Int=-1, effectType:Int=-1, effectParameter:Int=-1):Int
```
	
The new interactive functions "jump" and "queueNoteData" make it possible
to create custom XM-files that will work as sound banks/FX-bank.
Sounds can be played back either by triggering notes/instrument/samples directly
at any time or by jumping to specific patterns that play a certain sound setup
(like "got coin", "boss appears" or "danger - danger").

Please note that the note data specified in "queueNoteData" will not
replace the original pattern data, and it will only be read once.
This read happens when the playback enters the next row. Subsequent
calls to "queueNoteData" will thus only REPLACE the next enqueued note data -
it will not stack up! It is therefore not possible to create a virtual
*pattern* with this function. Think of this function as an opportunity
to execute any typical tracker command at the time of playback of
the next row and at that row only.

Interactive Example 1 (jumping):

```haxe
	var p:Player = new Player(44100, Player.INTERPOLATION_MODE_LINEAR);
	var m1:Int = p.loadXM(openfl.Assets.getBytes("assets/songBank01.xm"), -1)
	p.play(m1, true, true);
	
	// this will jump to row 44 of the pattern specified by the pattern order table at index 2
	// currently playing notes will be left hanging - this just jumps
	p.jump(m1, 2, 44, Player.JUMP_STYLE_JUMP);

	// this will jump to row 16 of the pattern specified by the pattern order table at index 3
	// currently playing notes will be "keyed-off" - allowing instruments to fade out
	p.jump(m1, 3, 16, Player.JUMP_STYLE_KEY_OFF_NOTES);

	// this will jump to row 56 in the current pattern
	// currently playing notes will be "cut" - instruments will stop playing immediately
	p.jump(m1, -1, 56, Player.JUMP_STYLE_KEY_CUT_NOTES);
```
	
Interactive Example 2 (note data insertion):

```haxe
	var p:Player = new Player(44100, Player.INTERPOLATION_MODE_LINEAR);
	var m1:Int = p.loadXM(openfl.Assets.getBytes("assets/songBank01.xm"), -1)
	p.play(m1, true, true);

	// at the next row this will set the tempo to 165 BPM (0xA5), and ticks/row speed to 0x04	
	// using the tracker command 0x0F.
	// channels will be selected at random if all channels are playing, otherwise
	// non-playing channels will be selected first
	p.queueNoteData(m1, -1, -1, -1, -1, 0xF, 0xA5);
	p.queueNoteData(m1, -1, -1, -1, -1, 0xF, 0x04);
	
	// at the next row this will play note 0x30 with volume column data 0x55 at channel 5
	// "-1" flags that the instrument, effect type and effect parameter data will be
	// copied from the original pattern
	p.queueNoteData(m1, 5, 0x30, -1, 0x55, -1, -1);
	
	// at the next row this will send a portamento slide down message (0x02) with
	// parameter data 0x0C to channel 3
	p.queueNoteData(m1, 3, -1, -1, -1, 0x02, 0x0C);
	
	// at the next row this will play note 0x50 with instrument 2, with random panning
	// (0xF + random byte) on an auto-selected channel, the volume column is left untouched
	p.queueNoteData(m1, -1, 0x50, 2, -1, 0x08, Std.int(Math.random() * 255));
```
	
A tip when entering global commands is that they should be allocated to a high
channel number. This assures that they will override similar commands already
queued or preset in the pattern (like a global volume set or a pattern order
command).

Another value to experiment and fine-tune would be the BUFFER_SIZE constant
set in "Player.hx". This value tells how many samples will
be written  to the device each time the SampleDataEvent is called and acts
as a cap on the latency of new data triggered by the interactive functions.
By default BUFFER_SIZE is set to 8192 samples in the HaXe version, but a
lower value of 2048 is much more snappier and much more "interactive".

A lower value will reduce latency, but a low value may tax the
cpu/playback device too much and may the stop the stream due or cause
audible droputs.

## Development Resources
The following files and sources have been very helpful in decoding the
.XM-file format and the playback effects:

	XM.TXT - by Triton with comments by ByteRaver & Wodan
	tracker_notes.txt - by Carraro & Matsuoka
	MODFILXX.TXT - by Thunder with comments by ByteRaver
	MilkyTracker.html - by the MilkyTracker team
	
For song creation and playback reference I've used OpenMPT.

## Downloads
TanjentXM is written and maintained by Jonas Murman at Tanjent. The
initial development started in the summer of 2013 and the first
version was released in January 2014.

The latest version of this library will be available at
http://www.tanjent.se/labs/tanjentxm.html (note: this site no longer exists)

## Reporting Issues
If you find a module that does not play correctly, please visit the
homepage and let me know!

If you manage to find a problem and correct it I would be very happy to
incorporate your changes to the library, provided you are ready to
license them under the MIT-license.

## License
TanjentXM is licensed under the MIT-license. This means that you can use
it free of charge, without strings attached in commercial and
non-commercial projects. Please read LICENSE for the full license.

