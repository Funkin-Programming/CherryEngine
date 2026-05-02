package;

import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import openfl.system.System;
#if mobile
import mobile.CopyState;
#end
#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#end

using StringTools;

class Main extends Sprite
{
	var game = {
		width: 1280,
		height: 720,
		initialState: TitleState,
		zoom: -1.0,
		framerate: 60,
		skipSplash: true,
		startFullscreen: false
	};

	public static var fpsVar:FPS;
	public static var skipNextDump:Bool = false;

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		#if mobile
		#if android
		StorageUtil.requestPermissions();
		#end
		Sys.setCwd(StorageUtil.getStorageDirectory());
		#end

		CrashHandler.init();

		#if windows
		@:functionCode("
		#include <windows.h>
		#include <winuser.h>
		setProcessDPIAware()
		DisableProcessWindowsGhosting()
		")
		#end

		super();

		if (stage != null)
			init();
		else
			addEventListener(Event.ADDED_TO_STAGE, init);
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
			removeEventListener(Event.ADDED_TO_STAGE, init);

		setupGame();
	}

	private function setupGame():Void
	{
		#if (openfl <= "9.2.0")
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (game.zoom == -1)
		{
			var ratioX:Float = stageWidth / game.width;
			var ratioY:Float = stageHeight / game.height;
			game.zoom = Math.min(ratioX, ratioY);
			game.width = Math.ceil(stageWidth / game.zoom);
			game.height = Math.ceil(stageHeight / game.zoom);
		}
		#else
		if (game.zoom == -1.0)
			game.zoom = 1.0;
		#end

		ClientPrefs.loadDefaultKeys();

		addChild(new FlxGame(
			#if mobile 0, 0 #else game.width, game.height #end,
			#if (mobile && MODS_ALLOWED) !CopyState.checkExistingFiles() ? CopyState : #end game.initialState,
			#if (flixel < "5.0.0") game.zoom, #end
			game.framerate, game.framerate,
			game.skipSplash,
			#if mobile true #else game.startFullscreen #end
		));

		FlxG.signals.preStateSwitch.add(function()
		{
			if (!skipNextDump)
			{
				Paths.clearStoredMemory();
				FlxG.bitmap.dumpCache();
			}
			clearMemory();
		});

		FlxG.signals.postStateSwitch.add(function()
		{
			Paths.clearUnusedMemory();
			clearMemory();
			skipNextDump = false;
		});

		FlxG.signals.gameResized.add(function(w:Int, h:Int)
		{
			if (fpsVar != null)
				fpsVar.x = 10;

			if (FlxG.cameras != null)
			{
				for (cam in FlxG.cameras.list)
				{
					@:privateAccess
					if (cam != null && cam._filters != null)
						resetSpriteCache(cam.flashSprite);
				}
			}

			if (FlxG.game != null)
				resetSpriteCache(FlxG.game);
		});

		#if !mobile
		fpsVar = new FPS(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		if (fpsVar != null)
			fpsVar.visible = ClientPrefs.showFPS;
		#end

		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		#if mobile
		FlxG.autoPause = false;
		FlxG.fixedTimestep = false;
		lime.system.System.allowScreenTimeout = ClientPrefs.screensaver;
		#if android
		FlxG.android.preventDefaultKeys = [BACK];
		#end
		#end
	}

	static function resetSpriteCache(sprite:Sprite):Void
	{
		@:privateAccess
		{
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
			sprite.__cacheBitmapData2 = null;
			sprite.__cacheBitmapData3 = null;
			sprite.__cacheBitmapColorTransform = null;
		}
	}

	public static function clearMemory():Void
	{
		#if cpp
		Gc.run(true);
		Gc.compact();
		#elseif hl
		Gc.major();
		#end
		System.gc();
	}
}