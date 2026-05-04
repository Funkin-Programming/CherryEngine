package backend;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import openfl.system.System;
import lime.app.Application;
#if mobile
import mobile.CopyState;
import mobile.backend.MobileScaleMode;
#end
#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#end

using StringTools;

class Main extends Sprite
{
	static inline var GAME_WIDTH:Int  = 1280;
	static inline var GAME_HEIGHT:Int = 720;
	static inline var FRAMERATE:Int   = 60;

	public static var fpsVar:openfl.display.FPS;
	public static var skipNextDump:Bool = false;
	public static var instance:Main;

	var _initialState:Class<FlxState> = TitleState;
	var _zoom:Float = -1.0;

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		instance = this;

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

		if (stage != null) init();
		else addEventListener(Event.ADDED_TO_STAGE, init);
	}

	private function init(?e:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
			removeEventListener(Event.ADDED_TO_STAGE, init);

		setupGame();
	}

	private function setupGame():Void
	{
		#if (openfl <= "9.2.0")
		var stageWidth:Int  = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (_zoom == -1.0)
		{
			var ratioX:Float = stageWidth  / GAME_WIDTH;
			var ratioY:Float = stageHeight / GAME_HEIGHT;
			_zoom = Math.min(ratioX, ratioY);
		}
		#else
		if (_zoom == -1.0) _zoom = 1.0;
		#end

		ClientPrefs.loadDefaultKeys();

		var initialState:Class<FlxState> =
			#if (mobile && MODS_ALLOWED)
			!CopyState.checkExistingFiles() ? CopyState :
			#end
			_initialState;

		addChild(new FlxGame(
			#if mobile 0, 0 #else GAME_WIDTH, GAME_HEIGHT #end,
			initialState,
			#if (flixel < "5.0.0") _zoom, #end
			FRAMERATE, FRAMERATE,
			true,
			#if mobile true #else false #end
		));

		setupSignals();
		setupFPS();
		setupStage();
		setupPlatform();
	}

	private function setupSignals():Void
	{
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

		FlxG.signals.gameResized.add(onGameResized);
		FlxG.signals.focusGained.add(onFocusGained);
		FlxG.signals.focusLost.add(onFocusLost);
	}

	private function setupFPS():Void
	{
		#if !mobile
		fpsVar = new openfl.display.FPS(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		if (fpsVar != null)
			fpsVar.visible = ClientPrefs.showFPS;
		#end
	}

	private function setupStage():Void
	{
		Lib.current.stage.align     = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
	}

	private function setupPlatform():Void
	{
		#if html5
		FlxG.autoPause     = false;
		FlxG.mouse.visible = false;
		#end

		#if mobile
		FlxG.autoPause     = false;
		FlxG.fixedTimestep = false;
		FlxG.scaleMode     = new MobileScaleMode();
		lime.system.System.allowScreenTimeout = ClientPrefs.screensaver;
		#if android
		FlxG.android.preventDefaultKeys = [BACK];
		#end
		#end

		#if desktop
		FlxG.stage.addEventListener(openfl.events.KeyboardEvent.KEY_UP, onKeyUp);
		#end
	}

	#if desktop
	private function onKeyUp(e:openfl.events.KeyboardEvent):Void
	{
		if (Controls.instance != null && Controls.instance.FULLSCREEN)
			FlxG.fullscreen = !FlxG.fullscreen;
	}
	#end

	private function onFocusGained():Void
	{
		#if mobile
		lime.system.System.allowScreenTimeout = ClientPrefs.screensaver;
		#end
	}

	private function onFocusLost():Void
	{
		#if mobile
		lime.system.System.allowScreenTimeout = true;
		#end
	}

	private function onGameResized(w:Int, h:Int):Void
	{
		#if !mobile
		if (fpsVar != null)
		{
			fpsVar.x = 10;
			fpsVar.y = 3;
		}
		#end

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
	}

	public static function resetSpriteCache(sprite:Sprite):Void
	{
		@:privateAccess
		{
			sprite.__cacheBitmap              = null;
			sprite.__cacheBitmapData          = null;
			sprite.__cacheBitmapData2         = null;
			sprite.__cacheBitmapData3         = null;
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

	public static function getAppTitle():String
	{
		var t = Application.current.meta.get('title');
		return t != null ? t : 'FNF: Cherry Engine';
	}

	public static function getAppVersion():String
	{
		var v = Application.current.meta.get('version');
		return v != null ? v : '0.1.0';
	}

	public static function setFPSVisible(v:Bool):Void
	{
		#if !mobile
		if (fpsVar != null) fpsVar.visible = v;
		#end
	}

	public static function setFramerate(fps:Int):Void
	{
		FlxG.updateFramerate = fps;
		FlxG.drawFramerate   = fps;
	}

	public static function toggleFullscreen():Void
	{
		#if desktop
		FlxG.fullscreen = !FlxG.fullscreen;
		#end
	}
}
