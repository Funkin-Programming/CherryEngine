package mobile.backend;

import flixel.FlxG;
import openfl.Lib;

class MobileScaleMode extends flixel.system.scaleModes.BaseScaleMode
{
	override function updateGameSize(width:Int, height:Int):Void
	{
		var stageW:Float = Lib.current.stage.stageWidth;
		var stageH:Float = Lib.current.stage.stageHeight;

		if (stageW <= 0 || stageH <= 0)
		{
			gameSize.set(width, height);
			return;
		}

		var ratioX:Float = stageW / FlxG.width;
		var ratioY:Float = stageH / FlxG.height;
		var scale:Float  = Math.min(ratioX, ratioY);

		gameSize.set(
			Math.ceil(FlxG.width  * scale),
			Math.ceil(FlxG.height * scale)
		);
	}

	override function updateDeviceSize(width:Int, height:Int):Void
	{
		deviceSize.set(
			Lib.current.stage.stageWidth,
			Lib.current.stage.stageHeight
		);
	}

	override function updateOffsetX():Void
	{
		offset.x = Math.round((deviceSize.x - gameSize.x) / 2);
	}

	override function updateOffsetY():Void
	{
		offset.y = Math.round((deviceSize.y - gameSize.y) / 2);
	}
}
