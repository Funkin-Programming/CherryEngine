package mobile.system;

import flixel.FlxG;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import openfl.display.Stage;
import openfl.display.StageDisplayState;
import openfl.events.Event;
import openfl.geom.Rectangle;
import openfl.Lib;
import lime.app.Application;
import lime.system.System as LimeSystem;

enum ScaleMode
{
	FIT;
	FILL;
	STRETCH;
	PIXEL_PERFECT;
	LETTERBOX;
	NATIVE;
}

typedef ScaleInfo =
{
	var scaleX:Float;
	var scaleY:Float;
	var offsetX:Float;
	var offsetY:Float;
	var width:Float;
	var height:Float;
}

class FullScreenScale
{
	static inline var BASE_WIDTH:Int  = 1280;
	static inline var BASE_HEIGHT:Int = 720;

	public static var currentMode(default, null):ScaleMode = LETTERBOX;
	public static var isFullscreen(default, null):Bool = false;
	public static var onScaleChanged:Array<ScaleInfo->Void> = [];

	static var _initialized:Bool = false;
	static var _lastWidth:Int  = 0;
	static var _lastHeight:Int = 0;

	public static function init(?mode:ScaleMode):Void
	{
		if (_initialized) return;
		_initialized = true;

		if (mode != null) currentMode = mode;

		Lib.current.stage.addEventListener(Event.RESIZE, _onResize);

		#if mobile
		Lib.current.stage.addEventListener(Event.ACTIVATE,   _onActivate);
		Lib.current.stage.addEventListener(Event.DEACTIVATE, _onDeactivate);
		#end

		apply(currentMode);
	}

	public static function apply(?mode:ScaleMode):Void
	{
		if (mode != null) currentMode = mode;

		var stageW:Int = Lib.current.stage.stageWidth;
		var stageH:Int = Lib.current.stage.stageHeight;

		if (stageW <= 0 || stageH <= 0) return;

		var info:ScaleInfo = _compute(stageW, stageH, currentMode);

		_applyToGame(info);
		_applyToCameras(info);
		_dispatchChanged(info);

		_lastWidth  = stageW;
		_lastHeight = stageH;
	}

	public static function setMode(mode:ScaleMode):Void
	{
		currentMode = mode;
		apply();
	}

	public static function toggleFullscreen():Void
	{
		#if desktop
		FlxG.fullscreen = !FlxG.fullscreen;
		isFullscreen = FlxG.fullscreen;
		apply();
		#elseif mobile
		var stage = Lib.current.stage;
		if (stage.displayState == StageDisplayState.FULL_SCREEN_INTERACTIVE)
		{
			stage.displayState = StageDisplayState.NORMAL;
			isFullscreen = false;
		}
		else
		{
			stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
			isFullscreen = true;
		}
		apply();
		#end
	}

	public static function getScaleInfo():ScaleInfo
	{
		var stageW:Int = Lib.current.stage.stageWidth;
		var stageH:Int = Lib.current.stage.stageHeight;
		return _compute(stageW, stageH, currentMode);
	}

	public static function getScale():Float
	{
		var info = getScaleInfo();
		return Math.min(info.scaleX, info.scaleY);
	}

	public static function getAspectRatio():Float
	{
		var stageW:Int = Lib.current.stage.stageWidth;
		var stageH:Int = Lib.current.stage.stageHeight;
		return stageW / stageH;
	}

	public static function getBaseAspectRatio():Float
		return BASE_WIDTH / BASE_HEIGHT;

	public static function isLandscape():Bool
	{
		var stageW:Int = Lib.current.stage.stageWidth;
		var stageH:Int = Lib.current.stage.stageHeight;
		return stageW >= stageH;
	}

	public static function getViewportRect():FlxRect
	{
		var info = getScaleInfo();
		return FlxRect.get(info.offsetX, info.offsetY, info.width, info.height);
	}

	public static function screenToGame(screenX:Float, screenY:Float):flixel.math.FlxPoint
	{
		var info = getScaleInfo();
		var gx = (screenX - info.offsetX) / info.scaleX;
		var gy = (screenY - info.offsetY) / info.scaleY;
		return flixel.math.FlxPoint.get(gx, gy);
	}

	public static function gameToScreen(gameX:Float, gameY:Float):flixel.math.FlxPoint
	{
		var info = getScaleInfo();
		var sx = gameX * info.scaleX + info.offsetX;
		var sy = gameY * info.scaleY + info.offsetY;
		return flixel.math.FlxPoint.get(sx, sy);
	}

	public static function addListener(fn:ScaleInfo->Void):Void
	{
		if (!onScaleChanged.contains(fn))
			onScaleChanged.push(fn);
	}

	public static function removeListener(fn:ScaleInfo->Void):Void
		onScaleChanged.remove(fn);

	public static function clearListeners():Void
		onScaleChanged = [];

	public static function destroy():Void
	{
		Lib.current.stage.removeEventListener(Event.RESIZE, _onResize);
		#if mobile
		Lib.current.stage.removeEventListener(Event.ACTIVATE,   _onActivate);
		Lib.current.stage.removeEventListener(Event.DEACTIVATE, _onDeactivate);
		#end
		clearListeners();
		_initialized = false;
	}

	static function _compute(stageW:Int, stageH:Int, mode:ScaleMode):ScaleInfo
	{
		var sx:Float = 1;
		var sy:Float = 1;
		var ox:Float = 0;
		var oy:Float = 0;
		var w:Float  = stageW;
		var h:Float  = stageH;

		switch (mode)
		{
			case FIT | LETTERBOX:
				sx = Math.min(stageW / BASE_WIDTH, stageH / BASE_HEIGHT);
				sy = sx;
				w  = BASE_WIDTH  * sx;
				h  = BASE_HEIGHT * sy;
				ox = (stageW - w) / 2;
				oy = (stageH - h) / 2;

			case FILL:
				sx = Math.max(stageW / BASE_WIDTH, stageH / BASE_HEIGHT);
				sy = sx;
				w  = BASE_WIDTH  * sx;
				h  = BASE_HEIGHT * sy;
				ox = (stageW - w) / 2;
				oy = (stageH - h) / 2;

			case STRETCH:
				sx = stageW / BASE_WIDTH;
				sy = stageH / BASE_HEIGHT;
				w  = stageW;
				h  = stageH;
				ox = 0;
				oy = 0;

			case PIXEL_PERFECT:
				var scale = Math.floor(Math.min(stageW / BASE_WIDTH, stageH / BASE_HEIGHT));
				if (scale < 1) scale = 1;
				sx = scale;
				sy = scale;
				w  = BASE_WIDTH  * scale;
				h  = BASE_HEIGHT * scale;
				ox = Math.floor((stageW - w) / 2);
				oy = Math.floor((stageH - h) / 2);

			case NATIVE:
				sx = 1;
				sy = 1;
				w  = stageW;
				h  = stageH;
				ox = 0;
				oy = 0;
		}

		return { scaleX: sx, scaleY: sy, offsetX: ox, offsetY: oy, width: w, height: h };
	}

	static function _applyToGame(info:ScaleInfo):Void
	{
		if (FlxG.game == null) return;

		FlxG.game.x = info.offsetX;
		FlxG.game.y = info.offsetY;
		FlxG.game.scaleX = info.scaleX;
		FlxG.game.scaleY = info.scaleY;
	}

	static function _applyToCameras(info:ScaleInfo):Void
	{
		if (FlxG.cameras == null) return;

		for (cam in FlxG.cameras.list)
		{
			if (cam == null) continue;

			@:privateAccess
			{
				if (cam._filters != null)
				{
					if (cam.flashSprite != null)
					{
						cam.flashSprite.__cacheBitmap             = null;
						cam.flashSprite.__cacheBitmapData         = null;
						cam.flashSprite.__cacheBitmapData2        = null;
						cam.flashSprite.__cacheBitmapData3        = null;
						cam.flashSprite.__cacheBitmapColorTransform = null;
					}
				}
			}
		}
	}

	static function _dispatchChanged(info:ScaleInfo):Void
	{
		for (fn in onScaleChanged)
			fn(info);
	}

	static function _onResize(e:Event):Void
	{
		var stageW:Int = Lib.current.stage.stageWidth;
		var stageH:Int = Lib.current.stage.stageHeight;

		if (stageW == _lastWidth && stageH == _lastHeight) return;

		apply();
	}

	#if mobile
	static function _onActivate(e:Event):Void
	{
		LimeSystem.allowScreenTimeout = ClientPrefs.screensaver;
		apply();
	}

	static function _onDeactivate(e:Event):Void
	{
		LimeSystem.allowScreenTimeout = true;
	}
	#end
}
