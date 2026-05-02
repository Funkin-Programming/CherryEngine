package options;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import Controls;

using StringTools;

class OptionsState extends MusicBeatState
{
	var options:Array<String> = [
		'Note Colors',
		'Controls',
		'Adjust Delay and Combo',
		'Graphics',
		'Visuals and UI',
		'Gameplay',
		#if mobile
		'Mobile Options'
		#end
	];

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private static var curSelected:Int = 0;

	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;
	var bg:FlxSprite;
	var bgTween:FlxTween;
	var exiting:Bool = false;
	var entering:Bool = true;

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		bg.alpha = 0;
		add(bg);
		FlxTween.tween(bg, {alpha: 1}, 0.6, {ease: FlxEase.quadOut});

		#if mobile
		var tipText:FlxText = new FlxText(150, FlxG.height - 24, 0, 'Press C to Go Mobile Controls Menu', 16);
		tipText.setFormat("VCR OSD Mono", 17, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tipText.borderSize = 1.25;
		tipText.scrollFactor.set();
		tipText.antialiasing = ClientPrefs.globalAntialiasing;
		tipText.alpha = 0;
		add(tipText);
		FlxTween.tween(tipText, {alpha: 1}, 0.5, {ease: FlxEase.quadOut, startDelay: 0.3});
		#end

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (i in 0...options.length)
		{
			var optionText:Alphabet = new Alphabet(0, 0, options[i], true);
			optionText.screenCenter();
			optionText.y += (100 * (i - (options.length / 2))) + 50;
			optionText.alpha = 0;
			optionText.x -= 200;
			grpOptions.add(optionText);

			var delay:Float = 0.05 * i + 0.1;
			FlxTween.tween(optionText, {alpha: 0.6, x: optionText.x + 200}, 0.5, {
				ease: FlxEase.backOut,
				startDelay: delay
			});
		}

		selectorLeft = new Alphabet(0, 0, '>', true);
		selectorLeft.alpha = 0;
		add(selectorLeft);
		selectorRight = new Alphabet(0, 0, '<', true);
		selectorRight.alpha = 0;
		add(selectorRight);

		new FlxTimer().start(0.4, function(_) {
			changeSelection();
			FlxTween.tween(selectorLeft, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
			FlxTween.tween(selectorRight, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
			entering = false;
		});

		ClientPrefs.saveSettings();

		#if mobile
		addTouchPad("UP_DOWN", "A_B_C");
		#end

		super.create();
	}

	override function closeSubState()
	{
		super.closeSubState();
		persistentUpdate = true;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		#if mobile
		removeTouchPad();
		addTouchPad("UP_DOWN", "A_B_C");
		#end

		ClientPrefs.saveSettings();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (entering || exiting) return;

		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);

		if (controls.BACK)
		{
			exiting = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));

			var i:Int = 0;
			for (item in grpOptions.members)
			{
				FlxTween.tween(item, {alpha: 0, x: item.x - 200}, 0.4, {
					ease: FlxEase.backIn,
					startDelay: 0.03 * i
				});
				i++;
			}
			FlxTween.tween(selectorLeft, {alpha: 0}, 0.3, {ease: FlxEase.quadIn});
			FlxTween.tween(selectorRight, {alpha: 0}, 0.3, {ease: FlxEase.quadIn});
			FlxTween.tween(bg, {alpha: 0}, 0.5, {
				ease: FlxEase.quadIn,
				startDelay: 0.1,
				onComplete: function(_) { MusicBeatState.switchState(new MainMenuState()); }
			});
		}
		else if (controls.ACCEPT)
		{
			openSelectedSubstate(options[curSelected]);
		}

		#if mobile
		if (touchPad != null && touchPad.buttonC.justPressed)
		{
			touchPad.active = touchPad.visible = persistentUpdate = false;
			openSubState(new mobile.MobileControlSelectSubState());
		}
		#end

		if (bgTween == null)
		{
			var targetColor:FlxColor = switch (curSelected % 6)
			{
				case 0: 0xFFea71fd;
				case 1: 0xFF71b8fd;
				case 2: 0xFF71fdac;
				case 3: 0xFFfdea71;
				case 4: 0xFFfd9171;
				case 5: 0xFFb471fd;
				default: 0xFFea71fd;
			};
			bgTween = FlxTween.color(bg, 0.5, bg.color, targetColor, {
				ease: FlxEase.sineInOut,
				onComplete: function(_) { bgTween = null; }
			});
		}
	}

	function openSelectedSubstate(label:String)
	{
		if (label != "Adjust Delay and Combo")
		{
			persistentUpdate = false;
			removeTouchPad();
		}

		switch (label)
		{
			case 'Note Colors':
				openSubState(new options.NotesSubState());
			case 'Controls':
				openSubState(new options.ControlsSubState());
			case 'Graphics':
				openSubState(new options.GraphicsSettingsSubState());
			case 'Visuals and UI':
				openSubState(new options.VisualsUISubState());
			case 'Gameplay':
				openSubState(new options.GameplaySettingsSubState());
			case 'Adjust Delay and Combo':
				LoadingState.loadAndSwitchState(new options.NoteOffsetState());
			#if mobile
			case 'Mobile Options':
				openSubState(new mobile.options.MobileOptionsSubState());
			#end
		}
	}

	function changeSelection(change:Int = 0)
	{
		curSelected += change;
		if (curSelected < 0) curSelected = options.length - 1;
		if (curSelected >= options.length) curSelected = 0;

		if (change != 0) FlxG.sound.play(Paths.sound('scrollMenu'));

		var i:Int = 0;
		for (item in grpOptions.members)
		{
			item.targetY = i - curSelected;
			i++;

			if (item.targetY == 0)
			{
				FlxTween.tween(item, {alpha: 1}, 0.15, {ease: FlxEase.quadOut});
				FlxTween.tween(selectorLeft, {x: item.x - 63, y: item.y}, 0.2, {ease: FlxEase.sineOut});
				FlxTween.tween(selectorRight, {x: item.x + item.width + 15, y: item.y}, 0.2, {ease: FlxEase.sineOut});
			}
			else
			{
				FlxTween.tween(item, {alpha: 0.6}, 0.15, {ease: FlxEase.quadOut});
			}
		}

		if (bgTween != null)
		{
			bgTween.cancel();
			bgTween = null;
		}
	}
}
