package;

import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.Graphics;
import openfl.display.Sprite;
import openfl.Lib;
import tanjent.tanjentxm.Player;
import flash.events.MouseEvent;
import tanjent.tanjentxm.XMModule;

class Main extends Sprite 
{

	var bgImage:Sprite;
			
	var currentModuleIndex:Int;
	var moduleIndices:Array<Int>;
		
	var p:Player;
	
	var currentSongSprite:Sprite;
	var jumpSprite:Sprite;
	
	public function new() 
	{
		super();
				
		this.p = new Player(44100, Player.INTERPOLATION_MODE_LINEAR);
		this.moduleIndices = new Array<Int>();
		this.moduleIndices.push(p.loadXM(openfl.Assets.getBytes("assets/chip18.xm"), -1));
		this.moduleIndices.push(p.loadXM(openfl.Assets.getBytes("assets/chip19.xm"), 0.25));
		this.moduleIndices.push(p.loadXM(openfl.Assets.getBytes("assets/chip20.xm"), -1));
		this.moduleIndices.push(p.loadXM(openfl.Assets.getBytes("assets/chip17.xm"), -1));
		this.currentModuleIndex = 0;
		
		bgImage = new Sprite();
		var bitmapData:Bitmap = new Bitmap(openfl.Assets.getBitmapData("assets/bg.png"));
		bgImage.addChild(bitmapData);
		bgImage.scaleX = 2;
		bgImage.scaleY = 2;
		bgImage.addEventListener(MouseEvent.CLICK, bgImageonClick);
		this.addChild(bgImage);
		
		this.currentSongSprite = new Sprite();
		this.currentSongSprite.graphics.beginFill(0x121212);
		this.currentSongSprite.graphics.drawCircle(0, 0, 12);
		this.currentSongSprite.graphics.endFill();
		this.currentSongSprite.graphics.beginFill(0x5ed462);
		this.currentSongSprite.graphics.drawCircle(0, 0, 8);
		this.currentSongSprite.graphics.endFill();
		this.currentSongSprite.x = -100;
		this.addChild(this.currentSongSprite);
		
		this.jumpSprite = new Sprite();
		this.jumpSprite.graphics.beginFill(0x121212);
		this.jumpSprite.graphics.drawCircle(0, 0, 12);
		this.jumpSprite.graphics.endFill();
		this.jumpSprite.graphics.beginFill(0xb40a34);
		this.jumpSprite.graphics.drawCircle(0, 0, 8);
		this.jumpSprite.graphics.endFill();
		this.jumpSprite.x = -100;
		this.addChild(this.jumpSprite);
	}
	
	public function bgImageonClick(event:MouseEvent)
	{
		
		if (event.localY > 16 && event.localY < 48) {
			if (event.localX > 16 && event.localX < 48) {
				this.currentModuleIndex = 0;
				this.currentSongSprite.x = 168 * 2 - 64 * 4;
				this.currentSongSprite.y = 80;
			}
			if (event.localX > 80 && event.localX < 112) {
				this.currentModuleIndex = 1;
				this.currentSongSprite.x = 168 * 2 - 64 * 2;
				this.currentSongSprite.y = 80;
			}
			if (event.localX > 144 && event.localX < 176) {
				this.currentModuleIndex = 2;
				this.currentSongSprite.x = 168 * 2;
				this.currentSongSprite.y = 80;
			}	
			if (event.localX > 208 && event.localX < 240) {
				this.currentModuleIndex = 3;
				this.currentSongSprite.x = 168 * 2 + 64 * 2;
				this.currentSongSprite.y = 80;
			}
			this.p.play(this.moduleIndices[this.currentModuleIndex], true, true);
		}
		
		if (event.localY > 16 && event.localY < 48) {
			if (event.localX > 272 && event.localX < 304) {
				this.p.stop();
			}
		}

		if (event.localY > 96) {		
			var xp:Float = event.localX - 16;
			var yp:Float = event.localY - 96;				
			xp /= 32;
			yp /= 32;				
			var xi:Int = Std.int(xp);
			var yi:Int = Std.int(yp);
						
			if (xi < 4 && yi < 4) {			
				if (currentModuleIndex == 0) {
					p.jump(this.moduleIndices[this.currentModuleIndex], (yi * 4) + xi, 0, Player.JUMP_STYLE_KEY_OFF_NOTES);					
				}				
				if (currentModuleIndex == 1) {
					p.jump(this.moduleIndices[this.currentModuleIndex], yi * 4 + 4, 16 * xi, Player.JUMP_STYLE_KEY_OFF_NOTES);					
				}				
				if (currentModuleIndex == 2) {		
					p.jump(this.moduleIndices[this.currentModuleIndex], yi, 16 * xi, Player.JUMP_STYLE_KEY_OFF_NOTES);
				}
				if (currentModuleIndex == 3) {		
					p.jump(this.moduleIndices[this.currentModuleIndex], 1 + yi, 32 * xi, Player.JUMP_STYLE_KEY_OFF_NOTES);
				}
				this.jumpSprite.x = 64 + 64 * xi;
				this.jumpSprite.y = 224 + 64 * yi;
			}
			
			if (xi == 6 && yi == 0) {
				// go fast
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], -1, -1, -1, -1, 0xF, 0x03);
			}
			if (xi == 8 && yi == 0) {
				// go slow
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], -1, -1, -1, -1, 0xF, 0x06);
			}
			
			if (xi == 6 && yi == 1) {
				// random chaos
				for (i in 0 ... 16) {
					p.queueNoteData(this.moduleIndices[this.currentModuleIndex], i, Std.int(Math.random() * 255), Std.int(Math.random()*255), Std.int(Math.random()*255), 0, 0);
				}
			}
			if (xi == 8 && yi == 1) {
				// key / silence all channels
				for (i in 0 ... 10) {
					p.queueNoteData(this.moduleIndices[this.currentModuleIndex], i, XMModule.NOTE_KEYOFF, 1, 0x64, 0xC, 0);
				}
			}
			
			if (xi == 6 && yi == 2) {
				// pitch bend up
				for (i in 0 ... 16) {
					p.queueNoteData(this.moduleIndices[this.currentModuleIndex], i, -1, -1, -1, 1, 0x06);
				}
			}
			if (xi == 8 && yi == 2) {
				// pitch bend down
				for (i in 0 ... 10) {
					p.queueNoteData(this.moduleIndices[this.currentModuleIndex], i, -1, -1, -1, 2, 0x06);
				}
			}
			
			if (xi == 6 && yi == 3) {
				// play a maj7 chord				
				var root:Int = Std.int(0x30 + Math.random() * 24);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 0, root + 0x00, 1, 0x30, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 1, root + 0x04, 1, 0x30, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 2, root + 0x07, 1, 0x30, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 3, root + 0x0B, 1, 0x30, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 4, XMModule.NOTE_KEYOFF, -1, -1, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 5, XMModule.NOTE_KEYOFF, -1, -1, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 6, XMModule.NOTE_KEYOFF, -1, -1, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 7, XMModule.NOTE_KEYOFF, -1, -1, -1, -1);
			}
			if (xi == 8 && yi == 3) {
				// play a min7 chord				
				var root:Int = Std.int(0x30 + Math.random() * 24);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 0, XMModule.NOTE_KEYOFF, -1, -1, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 1, XMModule.NOTE_KEYOFF, -1, -1, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 2, XMModule.NOTE_KEYOFF, -1, -1, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 3, XMModule.NOTE_KEYOFF, -1, -1, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 4, root + 0x00, 1, 0x30, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 5, root + 0x03, 1, 0x30, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 6, root + 0x07, 1, 0x30, -1, -1);
				p.queueNoteData(this.moduleIndices[this.currentModuleIndex], 7, root + 0x0A, 1, 0x30, -1, -1);
			}
		} 
	}
	
	
}
