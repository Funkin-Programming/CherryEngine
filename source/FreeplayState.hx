package;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import editors.ChartingState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.system.FlxSound;
import WeekData;
#if MODS_ALLOWED
import sys.FileSystem;
#end

using StringTools;

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	private static var curSelected:Int = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = '';

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<HealthIcon> = [];

	var bg:FlxSprite;
	var bgOverlay:FlxSprite;
	var bgDark:FlxSprite;
	var intendedColor:Int;
	var colorTween:FlxTween;

	var topBar:FlxSprite;
	var topBarAccent:FlxSprite;
	var bottomBar:FlxSprite;
	var leftEdge:FlxSprite;
	var scanline:FlxSprite;
	var scanline2:FlxSprite;
	var vignetteLeft:FlxSprite;
	var vignetteRight:FlxSprite;

	var titleText:FlxText;
	var songCountText:FlxText;
	var hintText:FlxText;
	var weekText:FlxText;

	var selectedCard:FlxSprite;
	var selectedGlow:FlxSprite;
	var selectedCardTag:FlxSprite;

	var particles:FlxTypedGroup<FlxSprite>;
	var particleVels:Array<Float> = [];
	var particleTimer:Float = 0;

	var waveSprites:FlxTypedGroup<FlxSprite>;
	var waveTimer:Float = 0;

	var entering:Bool = true;
	var exiting:Bool = false;

	var holdTime:Float = 0;
	var instPlaying:Int = -1;

	public static var vocals:FlxSound = null;

	public static function destroyFreeplayVocals()
	{
		if (vocals != null) { vocals.stop(); vocals.destroy(); }
		vocals = null;
	}

	override function create()
	{
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Freeplay", null);
		#end

		_loadSongs();
		_buildBG();
		_buildWaves();
		_buildParticles();
		_buildVignette();
		_buildSongList();
		_buildHUD();
		_buildScorePanel();

		if (curSelected >= songs.length) curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;

		if (lastDifficultyName == '')
			lastDifficultyName = CoolUtil.defaultDifficulty;
		curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(lastDifficultyName)));

		changeSelection(0, false);
		changeDiff();

		#if mobile
		addTouchPad("LEFT_FULL", "A_B_C_X_Y_Z");
		#end

		_playEnterAnim();

		super.create();
	}

	function _loadSongs()
	{
		for (i in 0...WeekData.weeksList.length)
		{
			if (weekIsLocked(WeekData.weeksList[i])) continue;
			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if (colors == null || colors.length < 3) colors = [146, 113, 253];
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		WeekData.loadTheFirstEnabledMod();
	}

	function _buildBG()
	{
		bgDark = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bgDark.scrollFactor.set();
		add(bgDark);

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		bg.screenCenter();
		bg.color = 0xFF888888;
		bg.alpha = 0;
		bg.scale.set(1.05, 1.05);
		add(bg);

		bgOverlay = FlxGridOverlay.create(28, 28, FlxG.width, FlxG.height, true, 0x05FFFFFF, 0x00000000);
		bgOverlay.scrollFactor.set();
		bgOverlay.alpha = 0;
		add(bgOverlay);

		scanline = new FlxSprite(0, -6).makeGraphic(FlxG.width, 4, 0x12FFFFFF);
		scanline.scrollFactor.set();
		add(scanline);

		scanline2 = new FlxSprite(0, FlxG.height / 2).makeGraphic(FlxG.width, 2, 0x08FFFFFF);
		scanline2.scrollFactor.set();
		add(scanline2);

		topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 54, 0xE00D0D1A);
		topBar.scrollFactor.set();
		topBar.y = -54;
		add(topBar);

		topBarAccent = new FlxSprite(0, 54).makeGraphic(FlxG.width, 3, 0xFF00D4FF);
		topBarAccent.scrollFactor.set();
		topBarAccent.y = -3;
		add(topBarAccent);

		leftEdge = new FlxSprite(0, 54).makeGraphic(3, FlxG.height - 54, 0xFF00D4FF);
		leftEdge.scrollFactor.set();
		leftEdge.x = -3;
		add(leftEdge);

		bottomBar = new FlxSprite(0, FlxG.height - 32).makeGraphic(FlxG.width, 32, 0xE00D0D1A);
		bottomBar.scrollFactor.set();
		bottomBar.y = FlxG.height;
		add(bottomBar);
	}

	function _buildWaves()
	{
		waveSprites = new FlxTypedGroup<FlxSprite>();
		add(waveSprites);
		for (i in 0...5)
		{
			var w = new FlxSprite(0, FlxG.height - 60 + i * 8).makeGraphic(FlxG.width, 2, 0x06FFFFFF);
			w.scrollFactor.set();
			w.alpha = 0;
			waveSprites.add(w);
		}
	}

	function _buildParticles()
	{
		particles = new FlxTypedGroup<FlxSprite>();
		add(particles);
		for (i in 0...18)
		{
			var size = FlxG.random.int(2, 6);
			var p = new FlxSprite(FlxG.random.float(0, FlxG.width), FlxG.random.float(0, FlxG.height));
			p.makeGraphic(size, size, 0x30FFFFFF);
			p.scrollFactor.set();
			p.alpha = 0;
			particles.add(p);
			particleVels.push(FlxG.random.float(8, 28));
		}
	}

	function _buildVignette()
	{
		vignetteLeft = new FlxSprite(0, 0).makeGraphic(180, FlxG.height, 0xFF000000);
		vignetteLeft.scrollFactor.set();
		vignetteLeft.alpha = 0.35;
		add(vignetteLeft);

		vignetteRight = new FlxSprite(FlxG.width - 180, 0).makeGraphic(180, FlxG.height, 0xFF000000);
		vignetteRight.scrollFactor.set();
		vignetteRight.alpha = 0.35;
		add(vignetteRight);
	}

	function _buildSongList()
	{
		selectedGlow = new FlxSprite(58, 0).makeGraphic(FlxG.width - 116, 62, 0x1AFFFFFF);
		selectedGlow.scrollFactor.set();
		add(selectedGlow);

		selectedCard = new FlxSprite(66, 0).makeGraphic(FlxG.width - 132, 54, 0xFF16213E);
		selectedCard.scrollFactor.set();
		add(selectedCard);

		selectedCardTag = new FlxSprite(66, 0).makeGraphic(5, 54, 0xFF00D4FF);
		selectedCardTag.scrollFactor.set();
		add(selectedCardTag);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.isMenuItem = true;
			songText.targetY = i - curSelected;
			songText.alpha = 0;
			grpSongs.add(songText);

			if (songText.width > 880)
				songText.scaleX = 880 / songText.width;
			songText.snapToPosition();

			Paths.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;
			icon.alpha = 0;
			iconArray.push(icon);
			add(icon);
		}
		WeekData.setDirectoryFromWeek();
	}

	function _buildHUD()
	{
		titleText = new FlxText(16, 14, 0, 'FREEPLAY', 22);
		titleText.setFormat('VCR OSD Mono', 22, 0xFF00D4FF, LEFT, FlxTextBorderStyle.OUTLINE, 0xFF001428);
		titleText.borderSize = 1.5;
		titleText.scrollFactor.set();
		titleText.y = -40;
		add(titleText);

		songCountText = new FlxText(FlxG.width - 130, 17, 120, '', 14);
		songCountText.setFormat('VCR OSD Mono', 14, 0xFF546E7A, RIGHT);
		songCountText.scrollFactor.set();
		add(songCountText);

		weekText = new FlxText(16, FlxG.height - 26, 0, '', 13);
		weekText.setFormat('VCR OSD Mono', 13, 0xFFFFCC02, LEFT);
		weekText.scrollFactor.set();
		add(weekText);

		final btnSpace:String = controls.mobileC ? 'X' : 'SPACE';
		final btnCtrl:String  = controls.mobileC ? 'C' : 'CTRL';
		final btnReset:String = controls.mobileC ? 'Y' : 'RESET';

		#if PRELOAD_ALL
		var hintStr = '$btnSpace: Preview  |  $btnCtrl: Options  |  $btnReset: Reset  |  SHIFT+OK: Chart';
		#else
		var hintStr = '$btnCtrl: Options  |  $btnReset: Reset  |  SHIFT+OK: Chart Editor';
		#end

		hintText = new FlxText(0, FlxG.height - 26, FlxG.width - 16, hintStr, 12);
		hintText.setFormat('VCR OSD Mono', 12, 0xFF37474F, RIGHT);
		hintText.scrollFactor.set();
		add(hintText);
	}

	function _buildScorePanel()
	{
		scoreBG = new FlxSprite(0, 57).makeGraphic(1, 66, 0xCC000000);
		scoreBG.scrollFactor.set();
		add(scoreBG);

		scoreText = new FlxText(FlxG.width * 0.68, 60, 0, '', 26);
		scoreText.setFormat('VCR OSD Mono', 26, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreText.borderSize = 1.5;
		scoreText.scrollFactor.set();
		add(scoreText);

		diffText = new FlxText(scoreText.x, scoreText.y + 32, 0, '', 20);
		diffText.setFormat('VCR OSD Mono', 20, 0xFF00D4FF, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		diffText.borderSize = 1;
		diffText.scrollFactor.set();
		add(diffText);
	}

	function _playEnterAnim()
	{
		FlxTween.tween(bg,        {alpha: 0.55}, 0.7, {ease: FlxEase.quadOut});
		FlxTween.tween(bgOverlay, {alpha: 1},    0.9, {ease: FlxEase.quadOut, startDelay: 0.15});
		FlxTween.tween(topBar,    {y: 0},        0.55, {ease: FlxEase.expoOut});
		FlxTween.tween(topBarAccent, {y: 54},    0.55, {ease: FlxEase.expoOut, startDelay: 0.04});
		FlxTween.tween(leftEdge,  {x: 0},        0.5, {ease: FlxEase.expoOut, startDelay: 0.1});
		FlxTween.tween(bottomBar, {y: FlxG.height - 32}, 0.55, {ease: FlxEase.expoOut, startDelay: 0.04});
		FlxTween.tween(titleText, {y: 14},       0.5, {ease: FlxEase.expoOut, startDelay: 0.12});

		for (i in 0...grpSongs.members.length)
		{
			var delay = 0.1 + i * 0.045;
			var item  = grpSongs.members[i];
			var icon  = iconArray[i];
			item.x = -600;
			FlxTween.tween(item, {alpha: 0.55, x: 90}, 0.55, {ease: FlxEase.expoOut, startDelay: delay});
			FlxTween.tween(icon, {alpha: 0.5},          0.4,  {ease: FlxEase.quadOut, startDelay: delay + 0.06});
		}

		for (i in 0...particles.members.length)
		{
			var p = particles.members[i];
			FlxTween.tween(p, {alpha: FlxG.random.float(0.04, 0.22)},
				FlxG.random.float(0.4, 1.2), {ease: FlxEase.quadOut, startDelay: FlxG.random.float(0, 1.0)});
		}

		for (i in 0...waveSprites.members.length)
			FlxTween.tween(waveSprites.members[i], {alpha: 0.6}, 0.8,
				{ease: FlxEase.quadOut, startDelay: 0.3 + i * 0.05});

		new FlxTimer().start(0.1 + grpSongs.members.length * 0.045 + 0.2, function(_) { entering = false; });
	}

	function _playExitAnim(onDone:Void->Void)
	{
		FlxTween.tween(bg,        {alpha: 0},   0.4, {ease: FlxEase.quadIn});
		FlxTween.tween(bgOverlay, {alpha: 0},   0.3, {ease: FlxEase.quadIn});
		FlxTween.tween(topBar,    {y: -54},     0.4, {ease: FlxEase.expoIn});
		FlxTween.tween(topBarAccent, {y: -3},   0.4, {ease: FlxEase.expoIn});
		FlxTween.tween(leftEdge,  {x: -3},      0.35,{ease: FlxEase.expoIn});
		FlxTween.tween(bottomBar, {y: FlxG.height}, 0.4, {ease: FlxEase.expoIn});
		FlxTween.tween(selectedCard, {alpha: 0}, 0.25, {ease: FlxEase.quadIn});
		FlxTween.tween(selectedGlow, {alpha: 0}, 0.25, {ease: FlxEase.quadIn});
		FlxTween.tween(selectedCardTag, {alpha: 0}, 0.2);

		for (i in 0...grpSongs.members.length)
		{
			var delay = i * 0.02;
			FlxTween.tween(grpSongs.members[i], {alpha: 0, x: grpSongs.members[i].x + 400}, 0.32,
				{ease: FlxEase.expoIn, startDelay: delay});
			FlxTween.tween(iconArray[i], {alpha: 0}, 0.2, {startDelay: delay});
		}

		new FlxTimer().start(0.5, function(_) { onDone(); });
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;

		#if mobile
		removeTouchPad();
		addTouchPad("LEFT_FULL", "A_B_C_X_Y_Z");
		#end

		super.closeSubState();
	}

	override function update(elapsed:Float)
	{
		_animateScanlines(elapsed);
		_animateParticles(elapsed);
		_animateWaves(elapsed);
		_animateCards();

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * FlxG.elapsed;

		lerpScore  = Math.floor(FlxMath.lerp(lerpScore,  intendedScore,  CoolUtil.boundTo(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, CoolUtil.boundTo(elapsed * 12, 0, 1));
		if (Math.abs(lerpScore  - intendedScore)  <= 10)   lerpScore  = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01) lerpRating = intendedRating;

		var ratingSplit = Std.string(Highscore.floorDecimal(lerpRating * 100, 2)).split('.');
		if (ratingSplit.length < 2) ratingSplit.push('');
		while (ratingSplit[1].length < 2) ratingSplit[1] += '0';

		scoreText.text = 'BEST: ' + lerpScore + ' (' + ratingSplit.join('.') + '%)';
		positionHighscore();

		if (entering || exiting) { super.update(elapsed); return; }

		var upP      = controls.UI_UP_P;
		var downP    = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT;

		#if mobile
		var space     = touchPad.buttonX.justPressed || FlxG.keys.justPressed.SPACE;
		var ctrl      = touchPad.buttonC.justPressed || FlxG.keys.justPressed.CONTROL;
		var shiftMult = (touchPad.buttonZ.pressed || FlxG.keys.pressed.SHIFT) ? 3 : 1;
		#else
		var space     = FlxG.keys.justPressed.SPACE;
		var ctrl      = FlxG.keys.justPressed.CONTROL;
		var shiftMult = FlxG.keys.pressed.SHIFT ? 3 : 1;
		#end

		if (songs.length > 1)
		{
			if (upP)   { changeSelection(-shiftMult); holdTime = 0; }
			if (downP) { changeSelection(shiftMult);  holdTime = 0; }

			if (controls.UI_DOWN || controls.UI_UP)
			{
				var checkLastHold = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var checkNewHold = Math.floor((holdTime - 0.5) * 10);
				if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
			}

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
				changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				changeDiff();
			}
		}

		if (controls.UI_LEFT_P)       changeDiff(-1);
		else if (controls.UI_RIGHT_P) changeDiff(1);
		else if (upP || downP)        changeDiff();

		if (controls.BACK)
		{
			exiting = true;
			if (colorTween != null) colorTween.cancel();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			_playExitAnim(function() MusicBeatState.switchState(new MainMenuState()));
			return;
		}

		if (ctrl)
		{
			persistentUpdate = false;
			#if mobile touchPad.active = touchPad.visible = false; #end
			openSubState(new GameplayChangersSubstate());
		}
		else if (space)
		{
			#if PRELOAD_ALL
			if (instPlaying != curSelected)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				Paths.currentModDirectory = songs[curSelected].folder;
				var poop = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				PlayState.SONG = Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
				vocals = PlayState.SONG.needsVoices
					? new FlxSound().loadEmbedded(Paths.voices(PlayState.SONG.song))
					: new FlxSound();
				FlxG.sound.list.add(vocals);
				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7);
				vocals.play();
				vocals.persist = vocals.looped = true;
				vocals.volume  = 0.7;
				instPlaying = curSelected;
			}
			#end
		}
		else if (accepted)
		{
			exiting = true;
			var songLowercase = Paths.formatToSongPath(songs[curSelected].songName);
			var poop = Highscore.formatSong(songLowercase, curDifficulty);
			PlayState.SONG = Song.loadFromJson(poop, songLowercase);
			PlayState.isStoryMode    = false;
			PlayState.storyDifficulty = curDifficulty;
			if (colorTween != null) colorTween.cancel();
			FlxG.sound.music.volume = 0;
			destroyFreeplayVocals();

			#if mobile
			var goChart = touchPad.buttonZ.pressed || FlxG.keys.pressed.SHIFT;
			#else
			var goChart = FlxG.keys.pressed.SHIFT;
			#end

			_playExitAnim(function()
			{
				if (goChart) LoadingState.loadAndSwitchState(new ChartingState());
				else         LoadingState.loadAndSwitchState(new PlayState());
			});
		}
		#if mobile
		else if (touchPad.buttonY.justPressed || controls.RESET)
		{
			touchPad.active = touchPad.visible = persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		#else
		else if (controls.RESET)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		#end

		super.update(elapsed);
	}

	function _animateScanlines(elapsed:Float)
	{
		scanline.y += 100 * elapsed;
		if (scanline.y > FlxG.height) scanline.y = -6;

		scanline2.y -= 55 * elapsed;
		if (scanline2.y < -6) scanline2.y = FlxG.height;
	}

	function _animateParticles(elapsed:Float)
	{
		particleTimer += elapsed;
		if (particleTimer > 0.05)
		{
			particleTimer = 0;
			for (i in 0...particles.members.length)
			{
				var p = particles.members[i];
				p.y -= particleVels[i] * 0.05;
				if (p.y < -10)
				{
					p.y = FlxG.height + 10;
					p.x = FlxG.random.float(0, FlxG.width);
				}
			}
		}
	}

	function _animateWaves(elapsed:Float)
	{
		waveTimer += elapsed;
		for (i in 0...waveSprites.members.length)
		{
			var w = waveSprites.members[i];
			w.y = (FlxG.height - 55 + i * 9) + Math.sin(waveTimer * 1.4 + i * 0.8) * 3;
		}
	}

	function _animateCards()
	{
		var targetY:Float = 0;
		for (item in grpSongs.members)
		{
			if (item.targetY == 0)
			{
				targetY = item.y + item.height / 2 - 27;
				break;
			}
		}

		selectedCard.y    = FlxMath.lerp(selectedCard.y,    targetY,      0.22);
		selectedGlow.y    = FlxMath.lerp(selectedGlow.y,    targetY - 4,  0.22);
		selectedCardTag.y = FlxMath.lerp(selectedCardTag.y, targetY,      0.22);
	}

	function changeDiff(change:Int = 0)
	{
		curDifficulty += change;
		if (curDifficulty < 0)                          curDifficulty = CoolUtil.difficulties.length - 1;
		if (curDifficulty >= CoolUtil.difficulties.length) curDifficulty = 0;

		lastDifficultyName = CoolUtil.difficulties[curDifficulty];

		#if !switch
		intendedScore  = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		PlayState.storyDifficulty = curDifficulty;
		diffText.text = '< ' + CoolUtil.difficultyString() + ' >';
		positionHighscore();
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;
		if (curSelected < 0)             curSelected = songs.length - 1;
		if (curSelected >= songs.length) curSelected = 0;

		var newColor:Int = songs[curSelected].color;
		if (newColor != intendedColor)
		{
			if (colorTween != null) colorTween.cancel();
			intendedColor = newColor;
			colorTween = FlxTween.color(bg, 0.75, bg.color, intendedColor, {
				ease: FlxEase.sineOut,
				onComplete: function(_) { colorTween = null; }
			});

			var accent  = FlxColor.fromInt(newColor).getLightened(0.25);
			var cardCol = FlxColor.fromInt(newColor).getDarkened(0.72);
			var glowCol = FlxColor.fromInt(newColor).getDarkened(0.55);
			FlxTween.color(topBarAccent,   0.35, topBarAccent.color,   accent);
			FlxTween.color(leftEdge,       0.35, leftEdge.color,       accent);
			FlxTween.color(selectedCardTag,0.3,  selectedCardTag.color, accent);
			FlxTween.color(selectedCard,   0.3,  selectedCard.color,   cardCol);
			FlxTween.color(selectedGlow,   0.3,  selectedGlow.color,   glowCol);
		}

		songCountText.text = (curSelected + 1) + ' / ' + songs.length;

		var weekName = WeekData.weeksLoaded.exists(WeekData.weeksList[songs[curSelected].week])
			? WeekData.weeksLoaded.get(WeekData.weeksList[songs[curSelected].week]).weekName : '';
		weekText.text = weekName.toUpperCase();

		#if !switch
		intendedScore  = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		for (i in 0...iconArray.length)
			iconArray[i].alpha = (i == curSelected) ? 1 : 0.45;

		var bullShit:Int = 0;
		for (item in grpSongs.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;
		}

		Paths.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;

		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		var diffStr:String = WeekData.getCurrentWeek().difficulties;
		if (diffStr != null) diffStr = diffStr.trim();
		if (diffStr != null && diffStr.length > 0)
		{
			var diffs = diffStr.split(',');
			var i = diffs.length - 1;
			while (i > 0)
			{
				if (diffs[i] != null)
				{
					diffs[i] = diffs[i].trim();
					if (diffs[i].length < 1) diffs.remove(diffs[i]);
				}
				--i;
			}
			if (diffs.length > 0 && diffs[0].length > 0) CoolUtil.difficulties = diffs;
		}

		if (CoolUtil.difficulties.contains(CoolUtil.defaultDifficulty))
			curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(CoolUtil.defaultDifficulty)));
		else
			curDifficulty = 0;

		var newPos = CoolUtil.difficulties.indexOf(lastDifficultyName);
		if (newPos > -1) curDifficulty = newPos;
	}

	private function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - scoreBG.scale.x / 2;
		diffText.x = Std.int(scoreBG.x + scoreBG.width / 2 - diffText.width / 2);
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return !leWeek.startUnlocked && leWeek.weekBefore.length > 0 &&
			(!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) ||
			 !StoryMenuState.weekCompleted.get(leWeek.weekBefore));
	}
}

class SongMetadata
{
	public var songName:String      = '';
	public var week:Int             = 0;
	public var songCharacter:String = '';
	public var color:Int            = -7179779;
	public var folder:String        = '';

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName      = song;
		this.week          = week;
		this.songCharacter = songCharacter;
		this.color         = color;
		this.folder = Paths.currentModDirectory != null ? Paths.currentModDirectory : '';
	}
}
