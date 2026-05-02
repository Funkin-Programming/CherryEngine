package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import flixel.addons.transition.FlxTransitionableState;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;

class OutdatedState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var warnText:FlxText;

	override function create()
	{
		super.create();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		var curVersion:String = Application.current.meta.get('version');
		var backKey:String = #if mobile "B" #else "ESCAPE" #end;

		warnText = new FlxText(0, 0, FlxG.width,
			"Hey! You're running an outdated version (" + curVersion + ").\n\n"
			+ "Please update to " + TitleState.updateVersion + "!\n\n"
			+ "Press ACCEPT to open the download page.\n"
			+ "Press " + backKey + " to proceed anyway.\n\n"
			+ "Thank you for using the Engine!",
			32);
		warnText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		add(warnText);
	}

	override function update(elapsed:Float)
	{
		if (!leftState)
		{
			if (controls.ACCEPT)
			{
				leftState = true;
				CoolUtil.browserLoad("https://github.com/AliAlafandy/FNF-PsychEngine-0.6.3-Template/releases");
			}
			else if (controls.BACK)
			{
				leftState = true;
			}

			#if mobile
			if (FlxG.touches.list.length > 0 && FlxG.touches.getFirst().justReleased)
				leftState = true;
			#end

			if (leftState)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxTween.tween(warnText, {alpha: 0}, 1, {
					onComplete: function(twn:FlxTween)
					{
						MusicBeatState.switchState(new MainMenuState());
					}
				});
			}
		}
		super.update(elapsed);
	}
}
