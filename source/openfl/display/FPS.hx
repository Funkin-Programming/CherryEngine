package openfl.display;

import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;

#if flash
import openfl.Lib;
#end

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class FPS extends TextField
{
	public var currentFPS(default, null):Int;

	@:noCompletion private var cacheCount:Int;
	@:noCompletion private var currentTime:Float;
	@:noCompletion private var times:Array<Float>;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		#if mobile
		this.x = 200;
		#else
		this.x = x;
		#end
		this.y = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 14, color);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		cacheCount = 0;
		currentTime = 0;
		times = [];

		#if flash
		addEventListener(Event.ENTER_FRAME, function(e)
		{
			var time = Lib.getTimer();
			__enterFrame(time - currentTime);
		});
		#end
	}

	@:noCompletion
	private #if !flash override #end function __enterFrame(deltaTime:Float):Void
	{
		currentTime += deltaTime;
		times.push(currentTime);

		while (times[0] < currentTime - 1000)
			times.shift();

		var currentCount = times.length;
		currentFPS = Math.round((currentCount + cacheCount) / 2);
		if (currentFPS > ClientPrefs.framerate) currentFPS = ClientPrefs.framerate;

		if (currentCount != cacheCount)
		{
			text = "FPS: " + currentFPS;
			textColor = currentFPS <= ClientPrefs.framerate / 2 ? 0xFFFF0000 : 0xFFFFFFFF;
		}

		cacheCount = currentCount;
	}
}