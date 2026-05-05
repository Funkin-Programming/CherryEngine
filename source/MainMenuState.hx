package;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import lime.app.Application;
import editors.MasterEditorMenu;
import Achievements;

using StringTools;

class MainMenuState extends MusicBeatState
{
	public static var curSelected:Int = 0;

	var menuItems:FlxTypedGroup<FlxSprite>;
	var camGame:FlxCamera;
	var camAchievement:FlxCamera;

	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED
		'mods',
		#end
		'credits',
		#if !switch
		'donate',
		#end
		'options'
	];

	var bg:FlxSprite;
	var magenta:FlxSprite;
	var bgShine:FlxSprite;
	var vignette:FlxSprite;
	var scanline:FlxSprite;
	var bottomBar:FlxSprite;
	var versionText:FlxText;

	var camFollow:FlxObject;
	var camFollowPos:FlxObject;

	var debugKeys:Array<FlxKey>;
	var selectedSomethin:Bool = false;
	var entering:Bool = true;

	var particles:FlxTypedGroup<FlxSprite>;
	var particleTimer:Float = 0;
	var particleSpeeds:Array<Float> = [];

	var shineX:Float = -200;
	var scanlineY:Float = 0;

	override function create()
	{
		#if MODS_ALLOWED
		Paths.pushGlobalMods();
		#end
		WeekData.loadTheFirstEnabledMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		debugKeys = ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1'));

		camGame        = new FlxCamera();
		camAchievement = new FlxCamera();
		camAchievement.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camAchievement, false);
		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		transIn  = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;
		persistentUpdate = persistentDraw = true;

		_buildBG();
		_buildParticles();
		_buildMenuItems();
		_buildHUD();

		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		Achievements.loadAchievements();
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
		{
			var achieveID:Int = Achievements.getAchievementIndex('friday_night_play');
			if (!Achievements.isAchievementUnlocked(Achievements.achievementsStuff[achieveID][2]))
			{
				Achievements.achievementsMap.set(Achievements.achievementsStuff[achieveID][2], true);
				_giveAchievement();
				ClientPrefs.saveSettings();
			}
		}
		#end

		#if mobile
		addTouchPad("UP_DOWN", "A_B_E");
		#end

		_playEnterAnim();

		super.create();
	}

	function _buildBG()
	{
		var yScroll:Float = Math.max(0.25 - (0.05 * (optionShit.length - 4)), 0.1);

		bg = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		bg.alpha = 0;
		add(bg);

		camFollow    = new FlxObject(0, 0, 1, 1);
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		add(camFollowPos);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.antialiasing = ClientPrefs.globalAntialiasing;
		magenta.color = 0xFFfd719b;
		add(magenta);

		vignette = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		vignette.scrollFactor.set();
		vignette.alpha = 0.35;
		add(vignette);

		scanline = new FlxSprite(0, 0).makeGraphic(FlxG.width, 3, 0x10FFFFFF);
		scanline.scrollFactor.set();
		add(scanline);

		bgShine = new FlxSprite(-80, 0).makeGraphic(80, FlxG.height, 0x18FFFFFF);
		bgShine.scrollFactor.set();
		bgShine.alpha = 0.5;
		add(bgShine);

		bottomBar = new FlxSprite(0, FlxG.height - 28).makeGraphic(FlxG.width, 28, 0xBB0D0D1A);
		bottomBar.scrollFactor.set();
		bottomBar.y = FlxG.height;
		add(bottomBar);

		FlxG.camera.follow(camFollowPos, null, 1);
	}

	function _buildParticles()
	{
		particles = new FlxTypedGroup<FlxSprite>();
		add(particles);

		for (i in 0...14)
		{
			var size = FlxG.random.int(1, 3);
			var p    = new FlxSprite(FlxG.random.float(0, FlxG.width), FlxG.random.float(0, FlxG.height));
			p.makeGraphic(size, size, 0x28FFFFFF);
			p.scrollFactor.set();
			p.alpha = 0;
			particles.add(p);
			particleSpeeds.push(FlxG.random.float(0.2, 0.9));
		}
	}

	function _buildMenuItems()
	{
		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		for (i in 0...optionShit.length)
		{
			var offset:Float  = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
			var menuItem:FlxSprite = new FlxSprite(0, (i * 140) + offset);
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + optionShit[i]);
			menuItem.animation.addByPrefix('idle',     optionShit[i] + " basic", 24);
			menuItem.animation.addByPrefix('selected', optionShit[i] + " white", 24);
			menuItem.animation.play('idle');
			menuItem.ID = i;
			menuItem.screenCenter(X);
			menuItem.scrollFactor.set(0, optionShit.length < 6 ? 0 : (optionShit.length - 4) * 0.135);
			menuItem.antialiasing = ClientPrefs.globalAntialiasing;
			menuItem.updateHitbox();
			menuItem.alpha = 0;
			menuItem.x    = -FlxG.width;
			menuItems.add(menuItem);
		}
	}

	function _buildHUD()
	{
		var appTitle   = backend.Main.getAppTitle();
		var appVersion = backend.Main.getAppVersion();

		versionText = new FlxText(12, FlxG.height - 22, 0, '$appTitle  v$appVersion', 12);
		versionText.scrollFactor.set();
		versionText.setFormat('VCR OSD Mono', 13, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionText.borderSize = 1.5;
		versionText.alpha = 0;
		add(versionText);
	}

	function _playEnterAnim()
	{
		FlxTween.tween(bg,       {alpha: 1},   0.7, {ease: FlxEase.quadOut});
		FlxTween.tween(bottomBar,{y: FlxG.height - 28}, 0.5, {ease: FlxEase.expoOut, startDelay: 0.1});

		for (i in 0...menuItems.members.length)
		{
			var item  = menuItems.members[i];
			var delay = 0.08 + i * 0.07;
			FlxTween.tween(item, {alpha: 1, x: 0}, 0.55, {ease: FlxEase.expoOut, startDelay: delay,
				onComplete: function(_)
				{
					item.screenCenter(X);
					if (i == menuItems.members.length - 1)
					{
						entering = false;
						FlxTween.tween(versionText, {alpha: 1}, 0.4, {ease: FlxEase.quadOut});
					}
				}
			});
		}

		for (i in 0...particles.members.length)
		{
			var p = particles.members[i];
			FlxTween.tween(p, {alpha: FlxG.random.float(0.04, 0.18)},
				FlxG.random.float(0.5, 1.4),
				{ease: FlxEase.quadOut, startDelay: FlxG.random.float(0, 1.0)});
		}
	}

	function _playExitAnim(onDone:Void->Void)
	{
		FlxTween.tween(bg,       {alpha: 0},  0.4, {ease: FlxEase.quadIn});
		FlxTween.tween(vignette, {alpha: 0},  0.3, {ease: FlxEase.quadIn});
		FlxTween.tween(bottomBar,{y: FlxG.height}, 0.35, {ease: FlxEase.expoIn});
		FlxTween.tween(versionText, {alpha: 0}, 0.2, {ease: FlxEase.quadIn});

		new FlxTimer().start(0.45, function(_) { onDone(); });
	}

	#if ACHIEVEMENTS_ALLOWED
	function _giveAchievement()
	{
		add(new AchievementObject('friday_night_play', camAchievement));
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
		trace('Giving achievement "friday_night_play"');
	}
	#end

	override function update(elapsed:Float)
	{
		_animateScanline(elapsed);
		_animateShine(elapsed);
		_animateParticles(elapsed);

		if (FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
			if (FreeplayState.vocals != null)
				FreeplayState.vocals.volume += 0.5 * elapsed;
		}

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 7.5, 0, 1);
		camFollowPos.setPosition(
			FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal),
			FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal)
		);

		if (!selectedSomethin && !entering)
		{
			if (controls.UI_UP_P)   { FlxG.sound.play(Paths.sound('scrollMenu')); changeItem(-1); }
			if (controls.UI_DOWN_P) { FlxG.sound.play(Paths.sound('scrollMenu')); changeItem(1);  }

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				_playExitAnim(function() MusicBeatState.switchState(new TitleState()));
			}
			else if (controls.ACCEPT)
			{
				if (optionShit[curSelected] == 'donate')
				{
					CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
				}
				else
				{
					selectedSomethin = true;
					FlxG.sound.play(Paths.sound('confirmMenu'));

					if (ClientPrefs.flashing)
						FlxFlicker.flicker(magenta, 1.1, 0.15, false);

					menuItems.forEach(function(spr:FlxSprite)
					{
						if (curSelected != spr.ID)
						{
							FlxTween.tween(spr, {alpha: 0, x: spr.x + 300}, 0.35, {
								ease: FlxEase.expoIn,
								startDelay: 0.02 * spr.ID,
								onComplete: function(_) { spr.kill(); }
							});
						}
						else
						{
							FlxFlicker.flicker(spr, 1, 0.06, false, false, function(flick:FlxFlicker)
							{
								_switchToSelected();
							});
						}
					});
				}
			}
			else if (#if mobile touchPad.buttonE.justPressed || #end FlxG.keys.anyJustPressed(debugKeys))
			{
				selectedSomethin = true;
				_playExitAnim(function() MusicBeatState.switchState(new MasterEditorMenu()));
			}
		}

		super.update(elapsed);

		menuItems.forEach(function(spr:FlxSprite) { spr.screenCenter(X); });
	}

	function _switchToSelected()
	{
		switch (optionShit[curSelected])
		{
			case 'story_mode': MusicBeatState.switchState(new StoryMenuState());
			case 'freeplay':   MusicBeatState.switchState(new FreeplayState());
			#if MODS_ALLOWED
			case 'mods':       MusicBeatState.switchState(new ModsMenuState());
			#end
			case 'credits':    MusicBeatState.switchState(new CreditsState());
			case 'options':    LoadingState.loadAndSwitchState(new options.OptionsState());
		}
	}

	function _animateScanline(elapsed:Float)
	{
		scanlineY += 80 * elapsed;
		if (scanlineY > FlxG.height) scanlineY = -3;
		scanline.y = scanlineY;
	}

	function _animateShine(elapsed:Float)
	{
		shineX += 180 * elapsed;
		if (shineX > FlxG.width + 80) shineX = -80;
		bgShine.x = shineX;
	}

	function _animateParticles(elapsed:Float)
	{
		particleTimer += elapsed;
		if (particleTimer > 0.06)
		{
			particleTimer = 0;
			for (i in 0...particles.members.length)
			{
				var p = particles.members[i];
				p.y -= particleSpeeds[i];
				if (p.y < -10) p.y = FlxG.height + 10;
			}
		}
	}

	function changeItem(huh:Int = 0)
	{
		curSelected += huh;
		if (curSelected >= menuItems.length) curSelected = 0;
		if (curSelected < 0)                curSelected = menuItems.length - 1;

		menuItems.forEach(function(spr:FlxSprite)
		{
			spr.animation.play('idle');
			spr.updateHitbox();

			if (spr.ID == curSelected)
			{
				spr.animation.play('selected');
				var add:Float = menuItems.length > 4 ? menuItems.length * 8 : 0;
				camFollow.setPosition(spr.getGraphicMidpoint().x, spr.getGraphicMidpoint().y - add);
				spr.centerOffsets();
				FlxTween.cancelTweensOf(spr, ['alpha']);
				FlxTween.tween(spr, {alpha: 1}, 0.12, {ease: FlxEase.quadOut});
			}
			else
			{
				FlxTween.cancelTweensOf(spr, ['alpha']);
				FlxTween.tween(spr, {alpha: 0.6}, 0.15, {ease: FlxEase.quadOut});
			}
		});
	}
}
