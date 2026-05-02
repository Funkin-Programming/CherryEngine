package editors;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
#if MODS_ALLOWED
import sys.FileSystem;
#end

using StringTools;

class MasterEditorMenu extends MusicBeatState
{
	var options:Array<String> = [
		'Chart Editor',
		'Character Editor',
		'Week Editor',
		'Menu Character Editor',
		'Dialogue Editor',
		'Dialogue Portrait Editor',
		'Modchart Editor',
	];

	var optionIcons:Array<String> = [
		'chart', 'character', 'week', 'menuchar', 'dialogue', 'portrait', 'modchart'
	];

	var optionColors:Array<Int> = [
		0xFF4FC3F7,
		0xFFF48FB1,
		0xFF81C784,
		0xFFFFB74D,
		0xFFCE93D8,
		0xFFFF8A65,
		0xFF00D4FF,
	];

	private var grpTexts:FlxTypedGroup<Alphabet>;
	private var grpCards:FlxTypedGroup<FlxSprite>;
	private var grpGlows:FlxTypedGroup<FlxSprite>;
	private var directories:Array<String> = [null];

	private var curSelected:Int = 0;
	private var curDirectory:Int = 0;
	private var directoryTxt:FlxText;
	private var descText:FlxText;
	private var counterText:FlxText;

	private var bg:FlxSprite;
	private var grid:FlxSprite;
	private var scanline:FlxSprite;
	private var topBar:FlxSprite;
	private var bottomBar:FlxSprite;
	private var sideLine:FlxSprite;
	private var accentLine:FlxSprite;

	private var entering:Bool = true;
	private var exiting:Bool = false;

	private var descMap:Map<String, String> = [
		'Chart Editor'             => 'Create and edit song charts with full note placement control.',
		'Character Editor'         => 'Design and preview characters with animations and offsets.',
		'Week Editor'              => 'Build story mode weeks with custom songs and unlocks.',
		'Menu Character Editor'    => 'Edit main menu freeplay character sprites.',
		'Dialogue Editor'          => 'Write and preview in-game dialogue cutscenes.',
		'Dialogue Portrait Editor' => 'Edit character portraits for dialogue boxes.',
		'Modchart Editor'          => 'Create advanced modcharts with keyframe animation tracks.',
	];

	override function create()
	{
		FlxG.mouse.visible = false;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Editors Main Menu", null);
		#end

		_buildBG();
		_buildCards();
		_buildHUD();

		#if MODS_ALLOWED
		for (folder in Paths.getModDirectories())
			directories.push(folder);
		var found:Int = directories.indexOf(Paths.currentModDirectory);
		if (found > -1) curDirectory = found;
		changeDirectory();
		#end

		changeSelection(0, true);

		#if mobile
		addTouchPad(#if MODS_ALLOWED "LEFT_FULL" #else "UP_DOWN" #end, "A_B");
		#end

		_playEnterAnim();

		super.create();
	}

	function _buildBG()
	{
		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF0D0D1A;
		bg.alpha = 0;
		add(bg);

		grid = FlxGridOverlay.create(40, 40, FlxG.width, FlxG.height, true, 0x08FFFFFF, 0x00000000);
		grid.scrollFactor.set();
		grid.alpha = 0;
		add(grid);

		scanline = new FlxSprite(0, 0);
		scanline.makeGraphic(FlxG.width, 2, 0x0CFFFFFF);
		scanline.scrollFactor.set();
		scanline.alpha = 0.5;
		add(scanline);

		topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 48, 0xFF16213E);
		topBar.scrollFactor.set();
		topBar.y = -48;
		add(topBar);

		accentLine = new FlxSprite(0, 48).makeGraphic(FlxG.width, 2, 0xFF00D4FF);
		accentLine.scrollFactor.set();
		accentLine.y = -2;
		add(accentLine);

		sideLine = new FlxSprite(0, 0).makeGraphic(3, FlxG.height, 0xFF00D4FF);
		sideLine.scrollFactor.set();
		sideLine.x = -3;
		add(sideLine);

		bottomBar = new FlxSprite(0, FlxG.height - 44).makeGraphic(FlxG.width, 44, 0xFF16213E);
		bottomBar.scrollFactor.set();
		bottomBar.y = FlxG.height;
		add(bottomBar);
	}

	function _buildCards()
	{
		grpGlows = new FlxTypedGroup<FlxSprite>();
		grpCards  = new FlxTypedGroup<FlxSprite>();
		grpTexts  = new FlxTypedGroup<Alphabet>();

		add(grpGlows);
		add(grpCards);
		add(grpTexts);

		for (i in 0...options.length)
		{
			var glow = new FlxSprite(60, 0).makeGraphic(FlxG.width - 120, 54, FlxColor.fromInt(optionColors[i]).getDarkened(0.7));
			glow.scrollFactor.set();
			glow.alpha = 0;
			grpGlows.add(glow);

			var card = new FlxSprite(70, 0).makeGraphic(FlxG.width - 140, 50, 0xFF16213E);
			card.scrollFactor.set();
			card.alpha = 0;
			grpCards.add(card);

			var tag = new FlxSprite(72, 0).makeGraphic(4, 50, FlxColor.fromInt(optionColors[i]));
			tag.scrollFactor.set();
			tag.alpha = 0;
			grpCards.add(tag);

			var leText:Alphabet = new Alphabet(90, 320, options[i], true);
			leText.isMenuItem = true;
			leText.targetY = i;
			leText.alpha = 0;
			grpTexts.add(leText);
			leText.snapToPosition();
		}
	}

	function _buildHUD()
	{
		var title = new FlxText(10, 12, 0, 'EDITOR HUB', 20);
		title.setFormat('VCR OSD Mono', 20, 0xFF00D4FF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF001428);
		title.borderSize = 1.5;
		title.scrollFactor.set();
		title.y = -40;
		add(title);
		FlxTween.tween(title, {y: 12}, 0.6, {ease: FlxEase.expoOut, startDelay: 0.1});

		counterText = new FlxText(FlxG.width - 150, 14, 140, '', 14);
		counterText.setFormat('VCR OSD Mono', 14, 0xFF607D8B, RIGHT);
		counterText.scrollFactor.set();
		add(counterText);

		descText = new FlxText(76, FlxG.height - 38, FlxG.width - 152, '', 14);
		descText.setFormat('VCR OSD Mono', 14, 0xFFB0BEC5, LEFT);
		descText.scrollFactor.set();
		add(descText);

		#if MODS_ALLOWED
		directoryTxt = new FlxText(0, FlxG.height - 38, FlxG.width, '', 14);
		directoryTxt.setFormat('VCR OSD Mono', 14, 0xFFFFCC02, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);
		#end
	}

	function _playEnterAnim()
	{
		FlxTween.tween(bg,       {alpha: 1},   0.5, {ease: FlxEase.quadOut});
		FlxTween.tween(grid,     {alpha: 1},   0.7, {ease: FlxEase.quadOut, startDelay: 0.1});
		FlxTween.tween(topBar,   {y: 0},       0.5, {ease: FlxEase.expoOut});
		FlxTween.tween(accentLine, {y: 48},    0.5, {ease: FlxEase.expoOut, startDelay: 0.05});
		FlxTween.tween(sideLine, {x: 0},       0.4, {ease: FlxEase.expoOut, startDelay: 0.1});
		FlxTween.tween(bottomBar, {y: FlxG.height - 44}, 0.5, {ease: FlxEase.expoOut, startDelay: 0.05});

		for (i in 0...grpTexts.members.length)
		{
			var delay = 0.15 + i * 0.06;
			var item = grpTexts.members[i];
			var card = grpCards.members[i * 2];
			var tag  = grpCards.members[i * 2 + 1];
			var glow = grpGlows.members[i];

			item.x = -400;
			FlxTween.tween(item, {alpha: 0.6, x: 90}, 0.5, {ease: FlxEase.expoOut, startDelay: delay});
			FlxTween.tween(card, {alpha: 0.5}, 0.4, {ease: FlxEase.quadOut, startDelay: delay});
			FlxTween.tween(tag,  {alpha: 1.0}, 0.4, {ease: FlxEase.quadOut, startDelay: delay});
		}

		new FlxTimer().start(0.15 + options.length * 0.06 + 0.1, function(_) { entering = false; });
	}

	override function update(elapsed:Float)
	{
		_animateScanline(elapsed);

		if (entering || exiting) { super.update(elapsed); return; }

		if (controls.UI_UP_P)   changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);

		#if MODS_ALLOWED
		if (controls.UI_LEFT_P)  changeDirectory(-1);
		if (controls.UI_RIGHT_P) changeDirectory(1);
		#end

		if (controls.BACK)
		{
			exiting = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			_playExitAnim(function() MusicBeatState.switchState(new MainMenuState()));
		}

		if (controls.ACCEPT) _selectEditor();

		_updateCards();

		super.update(elapsed);
	}

	function _animateScanline(elapsed:Float)
	{
		scanline.y += 120 * elapsed;
		if (scanline.y > FlxG.height) scanline.y = -2;
	}

	function _updateCards()
	{
		var bullShit:Int = 0;
		for (i in 0...grpTexts.members.length)
		{
			var item = grpTexts.members[i];
			var card = grpCards.members[i * 2];
			var tag  = grpCards.members[i * 2 + 1];
			var glow = grpGlows.members[i];

			item.targetY = bullShit - curSelected;
			bullShit++;

			var isSelected = (item.targetY == 0);
			item.alpha  = FlxMath.lerp(item.alpha,  isSelected ? 1.0 : 0.45, 0.2);
			card.alpha  = FlxMath.lerp(card.alpha,  isSelected ? 0.85 : 0.4,  0.2);
			glow.alpha  = FlxMath.lerp(glow.alpha,  isSelected ? 0.3 : 0.0,   0.15);

			var cardTargetY = item.y - 2;
			card.y = FlxMath.lerp(card.y, cardTargetY, 0.25);
			tag.y  = FlxMath.lerp(tag.y,  cardTargetY, 0.25);
			glow.y = FlxMath.lerp(glow.y, cardTargetY - 2, 0.25);
		}
	}

	function changeSelection(change:Int = 0, ?silent:Bool = false)
	{
		if (!silent) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;
		if (curSelected < 0)          curSelected = options.length - 1;
		if (curSelected >= options.length) curSelected = 0;

		counterText.text = (curSelected + 1) + ' / ' + options.length;

		descText.text = descMap.exists(options[curSelected]) ? descMap[options[curSelected]] : '';

		accentLine.color = FlxColor.fromInt(optionColors[curSelected]);
		sideLine.color   = FlxColor.fromInt(optionColors[curSelected]);
	}

	function _selectEditor()
	{
		exiting = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));

		var selectedIdx = curSelected;
		FlxTween.tween(grpTexts.members[curSelected], {x: FlxG.width + 100}, 0.35, {ease: FlxEase.expoIn});

		_playExitAnim(function()
		{
			FlxG.sound.music.volume = 0;
			#if PRELOAD_ALL
			FreeplayState.destroyFreeplayVocals();
			#end
			switch (options[selectedIdx])
			{
				case 'Character Editor':
					LoadingState.loadAndSwitchState(new CharacterEditorState(Character.DEFAULT_CHARACTER, false));
				case 'Week Editor':
					MusicBeatState.switchState(new WeekEditorState());
				case 'Menu Character Editor':
					MusicBeatState.switchState(new MenuCharacterEditorState());
				case 'Dialogue Portrait Editor':
					LoadingState.loadAndSwitchState(new DialogueCharacterEditorState(), false);
				case 'Dialogue Editor':
					LoadingState.loadAndSwitchState(new DialogueEditorState(), false);
				case 'Chart Editor':
					LoadingState.loadAndSwitchState(new ChartingState(), false);
				case 'Modchart Editor':
					MusicBeatState.switchState(new ModchartEditorState());
			}
		});
	}

	function _playExitAnim(onDone:Void->Void)
	{
		FlxTween.tween(bg,       {alpha: 0}, 0.4, {ease: FlxEase.quadIn});
		FlxTween.tween(grid,     {alpha: 0}, 0.3, {ease: FlxEase.quadIn});
		FlxTween.tween(topBar,   {y: -48},   0.4, {ease: FlxEase.expoIn});
		FlxTween.tween(accentLine, {y: -2},  0.4, {ease: FlxEase.expoIn});
		FlxTween.tween(sideLine, {x: -3},    0.35,{ease: FlxEase.expoIn});
		FlxTween.tween(bottomBar,{y: FlxG.height}, 0.4, {ease: FlxEase.expoIn});

		for (i in 0...grpTexts.members.length)
		{
			if (i == curSelected) continue;
			var delay = i * 0.03;
			FlxTween.tween(grpTexts.members[i], {alpha: 0, x: grpTexts.members[i].x - 200}, 0.3,
				{ease: FlxEase.expoIn, startDelay: delay});
			FlxTween.tween(grpCards.members[i * 2], {alpha: 0}, 0.2, {startDelay: delay});
		}

		new FlxTimer().start(0.45, function(_) { onDone(); });
	}

	#if MODS_ALLOWED
	function changeDirectory(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curDirectory += change;
		if (curDirectory < 0)                    curDirectory = directories.length - 1;
		if (curDirectory >= directories.length)  curDirectory = 0;

		WeekData.setDirectoryFromWeek();

		if (directories[curDirectory] == null || directories[curDirectory].length < 1)
			directoryTxt.text = '< NO MOD DIRECTORY LOADED >';
		else
		{
			Paths.currentModDirectory = directories[curDirectory];
			directoryTxt.text = '< MOD: ' + Paths.currentModDirectory.toUpperCase() + ' >';
		}
	}
	#end
}
