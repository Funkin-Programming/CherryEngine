package editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.input.keyboard.FlxKey;
import haxe.Json;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef ModchartEvent =
{
	var time:Float;
	var type:String;
	var target:String;
	var property:String;
	var value:Dynamic;
	var duration:Float;
	var ease:String;
	var ?tag:String;
}

typedef ModchartKeyframe =
{
	var time:Float;
	var value:Dynamic;
}

typedef ModchartTrack =
{
	var id:String;
	var target:String;
	var property:String;
	var color:Int;
	var keyframes:Array<ModchartKeyframe>;
}

typedef ModchartData =
{
	var version:String;
	var song:String;
	var bpm:Float;
	var events:Array<ModchartEvent>;
	var tracks:Array<ModchartTrack>;
}

class ModchartEditorState extends MusicBeatState
{
	static inline var TIMELINE_X:Float      = 240;
	static inline var TIMELINE_Y:Float      = 60;
	static inline var TIMELINE_W:Float      = 900;
	static inline var TIMELINE_H:Float      = 480;
	static inline var TRACK_HEIGHT:Float    = 36;
	static inline var HEADER_HEIGHT:Float   = 30;
	static inline var PIXELS_PER_BEAT:Float = 80;
	static inline var MIN_ZOOM:Float        = 0.25;
	static inline var MAX_ZOOM:Float        = 4.0;
	static inline var SNAP_VALUES:Array<Float> = [1, 0.5, 0.25, 0.125, 0.0625];

	var camUI:FlxCamera;
	var camTimeline:FlxCamera;

	var modData:ModchartData;
	var selectedTrack:Int = -1;
	var selectedKeyframe:Int = -1;
	var selectedEvent:Int = -1;

	var timelineZoom:Float = 1.0;
	var timelineScrollX:Float = 0;
	var timelineScrollY:Float = 0;
	var currentTime:Float = 0;
	var snapIndex:Int = 2;
	var isPlaying:Bool = false;
	var isDragging:Bool = false;
	var dragStartX:Float = 0;
	var dragStartTime:Float = 0;

	var undoStack:Array<String> = [];
	var redoStack:Array<String> = [];
	static inline var MAX_UNDO:Int = 50;

	var trackSprites:FlxTypedGroup<FlxSprite>;
	var keyframeSprites:FlxTypedGroup<FlxSprite>;
	var eventSprites:FlxTypedGroup<FlxSprite>;
	var cursorLine:FlxSprite;
	var playheadLine:FlxSprite;
	var selectionBox:FlxSprite;

	var bg:FlxSprite;
	var topBar:FlxSprite;
	var leftPanel:FlxSprite;
	var rightPanel:FlxSprite;
	var bottomBar:FlxSprite;
	var timelineArea:FlxSprite;
	var timelineMask:FlxSprite;

	var statusText:FlxText;
	var timeText:FlxText;
	var bpmText:FlxText;
	var snapText:FlxText;
	var zoomText:FlxText;
	var infoText:FlxText;

	var beatLines:FlxTypedGroup<FlxSprite>;
	var measureLines:FlxTypedGroup<FlxSprite>;

	var hoveringTrack:Int = -1;
	var hoveringTime:Float = 0;
	var contextMenuOpen:Bool = false;
	var contextMenuX:Float = 0;
	var contextMenuY:Float = 0;

	var propertyInputs:Map<String, String> = new Map();
	var editingProperty:String = null;

	static var _lastSongName:String = 'untitled';

	override function create()
	{
		super.create();

		FlxG.mouse.visible = true;

		camUI       = new FlxCamera();
		camTimeline = new FlxCamera();
		camTimeline.bgColor = 0xFF1A1A2E;

		FlxG.cameras.reset(camUI);
		FlxG.cameras.add(camTimeline, false);
		FlxCamera.defaultCameras = [camUI];

		_initData();
		_buildUI();
		_buildTimeline();
		_rebuildTracks();

		setStatus('Modchart Editor loaded. Press F1 for help.');
	}

	function _initData()
	{
		modData = {
			version: '1.0',
			song: _lastSongName,
			bpm: Conductor.bpm > 0 ? Conductor.bpm : 120,
			events: [],
			tracks: []
		};

		var defaultTracks:Array<{id:String, target:String, property:String, color:Int}> = [
			{id: 'bf_x',        target: 'boyfriend',   property: 'x',      color: 0xFF4FC3F7},
			{id: 'bf_y',        target: 'boyfriend',   property: 'y',      color: 0xFF81D4FA},
			{id: 'bf_alpha',    target: 'boyfriend',   property: 'alpha',  color: 0xFFB3E5FC},
			{id: 'bf_angle',    target: 'boyfriend',   property: 'angle',  color: 0xFF29B6F6},
			{id: 'dad_x',       target: 'dad',         property: 'x',      color: 0xFFF48FB1},
			{id: 'dad_y',       target: 'dad',         property: 'y',      color: 0xFFF06292},
			{id: 'dad_alpha',   target: 'dad',         property: 'alpha',  color: 0xFFEC407A},
			{id: 'cam_zoom',    target: 'camGame',     property: 'zoom',   color: 0xFFA5D6A7},
			{id: 'cam_x',       target: 'camGame',     property: 'x',      color: 0xFF66BB6A},
			{id: 'hud_alpha',   target: 'camHUD',      property: 'alpha',  color: 0xFFCE93D8},
			{id: 'speed',       target: 'playState',   property: 'speed',  color: 0xFFFFCC02},
			{id: 'health_gain', target: 'playState',   property: 'healthGain', color: 0xFFFF7043},
		];

		for (t in defaultTracks)
		{
			modData.tracks.push({
				id: t.id,
				target: t.target,
				property: t.property,
				color: t.color,
				keyframes: []
			});
		}
	}

	function _buildUI()
	{
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF0D0D1A);
		bg.scrollFactor.set();
		add(bg);

		topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 50, 0xFF16213E);
		topBar.scrollFactor.set();
		add(topBar);

		var topBorder = new FlxSprite(0, 50).makeGraphic(FlxG.width, 2, 0xFF0F3460);
		topBorder.scrollFactor.set();
		add(topBorder);

		leftPanel = new FlxSprite(0, 52).makeGraphic(238, FlxG.height - 52, 0xFF16213E);
		leftPanel.scrollFactor.set();
		add(leftPanel);

		var leftBorder = new FlxSprite(238, 52).makeGraphic(2, FlxG.height - 52, 0xFF0F3460);
		leftBorder.scrollFactor.set();
		add(leftBorder);

		rightPanel = new FlxSprite(FlxG.width - 240, 52).makeGraphic(240, FlxG.height - 52, 0xFF16213E);
		rightPanel.scrollFactor.set();
		add(rightPanel);

		var rightBorder = new FlxSprite(FlxG.width - 242, 52).makeGraphic(2, FlxG.height - 52, 0xFF0F3460);
		rightBorder.scrollFactor.set();
		add(rightBorder);

		bottomBar = new FlxSprite(240, FlxG.height - 30).makeGraphic(FlxG.width - 480, 30, 0xFF16213E);
		bottomBar.scrollFactor.set();
		add(bottomBar);

		var title = new FlxText(10, 14, 0, 'MODCHART EDITOR', 14);
		title.setFormat('VCR OSD Mono', 14, 0xFF00D4FF, LEFT);
		title.scrollFactor.set();
		add(title);

		_buildTopButtons();

		statusText = new FlxText(10, FlxG.height - 22, 0, '', 11);
		statusText.setFormat('VCR OSD Mono', 11, 0xFF607D8B, LEFT);
		statusText.scrollFactor.set();
		add(statusText);

		timeText = new FlxText(FlxG.width - 350, 14, 0, 'TIME: 0.00s  BEAT: 0.00', 12);
		timeText.setFormat('VCR OSD Mono', 12, 0xFF00D4FF, RIGHT);
		timeText.scrollFactor.set();
		add(timeText);

		snapText = new FlxText(FlxG.width - 600, 14, 0, 'SNAP: 1/4', 12);
		snapText.setFormat('VCR OSD Mono', 12, 0xFF78909C, LEFT);
		snapText.scrollFactor.set();
		add(snapText);

		zoomText = new FlxText(FlxG.width - 720, 14, 0, 'ZOOM: 100%', 12);
		zoomText.setFormat('VCR OSD Mono', 12, 0xFF78909C, LEFT);
		zoomText.scrollFactor.set();
		add(zoomText);

		bpmText = new FlxText(200, 14, 0, 'BPM: ${modData.bpm}', 12);
		bpmText.setFormat('VCR OSD Mono', 12, 0xFFFFCC02, LEFT);
		bpmText.scrollFactor.set();
		add(bpmText);

		_buildLeftPanel();
		_buildRightPanel();
	}

	function _buildTopButtons()
	{
		var btnData = [
			{label: 'NEW',    x: 130, key: 'N'},
			{label: 'OPEN',   x: 180, key: 'O'},
			{label: 'SAVE',   x: 230, key: 'S'},
			{label: 'EXPORT', x: 280, key: 'E'},
			{label: 'UNDO',   x: 360, key: 'Z'},
			{label: 'REDO',   x: 410, key: 'Y'},
		];

		for (b in btnData)
		{
			var btn = _makeButton(b.x, 10, 44, 28, b.label, 0xFF0F3460, 0xFF00D4FF);
			add(btn);
		}
	}

	function _buildLeftPanel()
	{
		var header = new FlxText(8, 60, 220, 'TRACKS', 11);
		header.setFormat('VCR OSD Mono', 11, 0xFF00D4FF, LEFT);
		header.scrollFactor.set();
		add(header);

		var addBtn = _makeButton(180, 58, 50, 20, '+ ADD', 0xFF1B5E20, 0xFF69F0AE);
		add(addBtn);

		infoText = new FlxText(8, FlxG.height - 180, 220, '', 10);
		infoText.setFormat('VCR OSD Mono', 10, 0xFF546E7A, LEFT);
		infoText.wordWrap = true;
		infoText.scrollFactor.set();
		add(infoText);
	}

	function _buildRightPanel()
	{
		var px = FlxG.width - 235;

		var header = new FlxText(px, 60, 220, 'PROPERTIES', 11);
		header.setFormat('VCR OSD Mono', 11, 0xFF00D4FF, LEFT);
		header.scrollFactor.set();
		add(header);

		var propLabels = ['Target', 'Property', 'Value', 'Duration', 'Ease', 'Tag'];
		for (i in 0...propLabels.length)
		{
			var lbl = new FlxText(px, 85 + i * 42, 100, propLabels[i] + ':', 10);
			lbl.setFormat('VCR OSD Mono', 10, 0xFF607D8B, LEFT);
			lbl.scrollFactor.set();
			add(lbl);

			var inputBg = new FlxSprite(px, 98 + i * 42).makeGraphic(220, 22, 0xFF0D0D1A);
			inputBg.scrollFactor.set();
			add(inputBg);

			var inputBorder = new FlxSprite(px - 1, 97 + i * 42).makeGraphic(222, 24, 0xFF0F3460);
			inputBorder.scrollFactor.set();
			insert(members.indexOf(inputBg), inputBorder);

			var inputText = new FlxText(px + 4, 101 + i * 42, 212, '-', 10);
			inputText.setFormat('VCR OSD Mono', 10, 0xFFECEFF1, LEFT);
			inputText.scrollFactor.set();
			add(inputText);
		}

		var applyBtn = _makeButton(px, 360, 220, 26, 'APPLY KEYFRAME', 0xFF1A237E, 0xFF82B1FF);
		add(applyBtn);

		var deleteBtn = _makeButton(px, 392, 106, 26, 'DELETE', 0xFF4A1010, 0xFFEF9A9A);
		add(deleteBtn);

		var clearBtn = _makeButton(px + 114, 392, 106, 26, 'CLEAR TRACK', 0xFF4A3500, 0xFFFFCC02);
		add(clearBtn);
	}

	function _buildTimeline()
	{
		camTimeline.setPosition(TIMELINE_X, TIMELINE_Y);
		camTimeline.setSize(Std.int(TIMELINE_W), Std.int(TIMELINE_H));
		camTimeline.zoom = 1;

		timelineArea = new FlxSprite(TIMELINE_X, TIMELINE_Y).makeGraphic(
			Std.int(TIMELINE_W), Std.int(TIMELINE_H), 0xFF1A1A2E);
		timelineArea.scrollFactor.set();
		add(timelineArea);

		var timelineBorder = new FlxSprite(TIMELINE_X - 1, TIMELINE_Y - 1).makeGraphic(
			Std.int(TIMELINE_W) + 2, Std.int(TIMELINE_H) + 2, 0xFF0F3460);
		timelineBorder.scrollFactor.set();
		insert(members.indexOf(timelineArea), timelineBorder);

		beatLines    = new FlxTypedGroup<FlxSprite>();
		measureLines = new FlxTypedGroup<FlxSprite>();
		trackSprites   = new FlxTypedGroup<FlxSprite>();
		keyframeSprites = new FlxTypedGroup<FlxSprite>();
		eventSprites   = new FlxTypedGroup<FlxSprite>();

		add(beatLines);
		add(measureLines);
		add(trackSprites);
		add(keyframeSprites);
		add(eventSprites);

		cursorLine = new FlxSprite(TIMELINE_X, TIMELINE_Y).makeGraphic(2, Std.int(TIMELINE_H), 0x8800D4FF);
		cursorLine.scrollFactor.set();
		add(cursorLine);

		playheadLine = new FlxSprite(TIMELINE_X, TIMELINE_Y).makeGraphic(2, Std.int(TIMELINE_H), 0xFFFFCC02);
		playheadLine.scrollFactor.set();
		add(playheadLine);

		selectionBox = new FlxSprite(0, 0).makeGraphic(1, 1, 0x4400D4FF);
		selectionBox.visible = false;
		selectionBox.scrollFactor.set();
		add(selectionBox);

		_rebuildBeatLines();
	}

	function _rebuildBeatLines()
	{
		beatLines.clear();
		measureLines.clear();

		var totalBeats:Int = 128;
		for (b in 0...totalBeats)
		{
			var x = TIMELINE_X + b * PIXELS_PER_BEAT * timelineZoom - timelineScrollX;
			if (x < TIMELINE_X || x > TIMELINE_X + TIMELINE_W) continue;

			var isMeasure = (b % 4 == 0);
			var line = new FlxSprite(x, TIMELINE_Y).makeGraphic(1, Std.int(TIMELINE_H),
				isMeasure ? 0x33FFFFFF : 0x15FFFFFF);
			line.scrollFactor.set();

			if (isMeasure)
			{
				var beatNum = new FlxText(x + 2, TIMELINE_Y + 2, 0, Std.string(b), 9);
				beatNum.setFormat('VCR OSD Mono', 9, 0xFF37474F, LEFT);
				beatNum.scrollFactor.set();
				beatLines.add(beatNum);

				measureLines.add(line);
			}
			else
				beatLines.add(line);
		}
	}

	function _rebuildTracks()
	{
		trackSprites.clear();
		keyframeSprites.clear();

		for (i in 0...modData.tracks.length)
		{
			var track = modData.tracks[i];
			var ty = TIMELINE_Y + HEADER_HEIGHT + i * TRACK_HEIGHT - timelineScrollY;

			if (ty + TRACK_HEIGHT < TIMELINE_Y || ty > TIMELINE_Y + TIMELINE_H) continue;

			var isSelected = (i == selectedTrack);

			var rowBg = new FlxSprite(TIMELINE_X, ty).makeGraphic(Std.int(TIMELINE_W), Std.int(TRACK_HEIGHT) - 1,
				isSelected ? 0xFF0F3460 : (i % 2 == 0 ? 0xFF161628 : 0xFF1A1A2E));
			rowBg.scrollFactor.set();
			trackSprites.add(rowBg);

			var colorBar = new FlxSprite(TIMELINE_X, ty).makeGraphic(4, Std.int(TRACK_HEIGHT) - 1, track.color);
			colorBar.scrollFactor.set();
			trackSprites.add(colorBar);

			for (kf in track.keyframes)
			{
				var kx = TIMELINE_X + kf.time * PIXELS_PER_BEAT * timelineZoom - timelineScrollX;
				if (kx < TIMELINE_X || kx > TIMELINE_X + TIMELINE_W) continue;

				var diamond = new FlxSprite(kx - 5, ty + TRACK_HEIGHT / 2 - 5);
				diamond.makeGraphic(10, 10, FlxColor.TRANSPARENT);
				_drawDiamond(diamond, track.color);
				diamond.scrollFactor.set();
				keyframeSprites.add(diamond);
			}
		}

		for (ev in modData.events)
		{
			var ex = TIMELINE_X + ev.time * PIXELS_PER_BEAT * timelineZoom - timelineScrollX;
			if (ex < TIMELINE_X || ex > TIMELINE_X + TIMELINE_W) continue;

			var evLine = new FlxSprite(ex, TIMELINE_Y).makeGraphic(1, Std.int(TIMELINE_H), 0x88FF6B6B);
			evLine.scrollFactor.set();
			eventSprites.add(evLine);

			var evLabel = new FlxText(ex + 2, TIMELINE_Y + 4, 0, ev.type, 8);
			evLabel.setFormat('VCR OSD Mono', 8, 0xFFFF6B6B, LEFT);
			evLabel.scrollFactor.set();
			eventSprites.add(evLabel);
		}

		_rebuildLeftTrackLabels();
	}

	function _rebuildLeftTrackLabels()
	{
		for (i in 0...modData.tracks.length)
		{
			var track = modData.tracks[i];
			var ty = TIMELINE_Y + HEADER_HEIGHT + i * TRACK_HEIGHT - timelineScrollY;
			if (ty + TRACK_HEIGHT < TIMELINE_Y || ty > TIMELINE_Y + TIMELINE_H) continue;

			var lbl = new FlxText(8, ty + 4, 220, track.target + '.' + track.property, 10);
			lbl.setFormat('VCR OSD Mono', 10, FlxColor.fromInt(track.color), LEFT);
			lbl.scrollFactor.set();
			trackSprites.add(lbl);

			var kfCount = new FlxText(195, ty + 4, 40, Std.string(track.keyframes.length), 10);
			kfCount.setFormat('VCR OSD Mono', 10, 0xFF37474F, RIGHT);
			kfCount.scrollFactor.set();
			trackSprites.add(kfCount);
		}
	}

	function _drawDiamond(spr:FlxSprite, color:Int)
	{
		var pixels = spr.pixels;
		var c = FlxColor.fromInt(color);
		pixels.setPixel32(5, 0, c);
		pixels.setPixel32(4, 1, c); pixels.setPixel32(5, 1, c); pixels.setPixel32(6, 1, c);
		pixels.setPixel32(3, 2, c); pixels.setPixel32(4, 2, c); pixels.setPixel32(5, 2, c); pixels.setPixel32(6, 2, c); pixels.setPixel32(7, 2, c);
		pixels.setPixel32(4, 3, c); pixels.setPixel32(5, 3, c); pixels.setPixel32(6, 3, c);
		pixels.setPixel32(5, 4, c);
		spr.loadGraphic(flixel.graphics.FlxGraphic.fromBitmapData(pixels));
	}

	function _makeButton(x:Float, y:Float, w:Int, h:Int, label:String, bgColor:Int, textColor:Int):FlxText
	{
		var bg = new FlxSprite(x, y).makeGraphic(w, h, bgColor);
		bg.scrollFactor.set();
		add(bg);

		var border = new FlxSprite(x - 1, y - 1).makeGraphic(w + 2, h + 2, FlxColor.fromInt(bgColor).getDarkened(0.3));
		border.scrollFactor.set();
		insert(members.indexOf(bg), border);

		var txt = new FlxText(x, y + (h - 10) / 2, w, label, 9);
		txt.setFormat('VCR OSD Mono', 9, textColor, CENTER);
		txt.scrollFactor.set();
		return txt;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		_handleKeyboard();
		_handleMouse();
		_updatePlayhead(elapsed);
		_updateHUD();
	}

	function _handleKeyboard()
	{
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new editors.MasterEditorMenu());
			return;
		}

		#if desktop
		if (FlxG.keys.pressed.CONTROL)
		{
			if (FlxG.keys.justPressed.Z) { undo(); return; }
			if (FlxG.keys.justPressed.Y) { redo(); return; }
			if (FlxG.keys.justPressed.S) { save(); return; }
			if (FlxG.keys.justPressed.O) { load(); return; }
			if (FlxG.keys.justPressed.D && selectedTrack >= 0 && selectedKeyframe >= 0)
			{
				_deleteSelectedKeyframe();
				return;
			}
		}
		#end

		if (FlxG.keys.justPressed.SPACE)
		{
			isPlaying = !isPlaying;
			if (isPlaying) setStatus('Playing...');
			else setStatus('Paused at beat ' + _toBeat(currentTime));
		}

		if (FlxG.keys.justPressed.HOME)  { currentTime = 0; timelineScrollX = 0; }
		if (FlxG.keys.justPressed.END)   { currentTime = _getLastBeat(); }

		if (FlxG.keys.justPressed.PLUS  || FlxG.keys.justPressed.NUMPADPLUS)  _changeZoom(1.25);
		if (FlxG.keys.justPressed.MINUS || FlxG.keys.justPressed.NUMPADMINUS) _changeZoom(0.8);

		if (FlxG.keys.justPressed.LBRACKET)  { snapIndex = Std.int(Math.min(snapIndex + 1, SNAP_VALUES.length - 1)); _updateSnapText(); }
		if (FlxG.keys.justPressed.RBRACKET)  { snapIndex = Std.int(Math.max(snapIndex - 1, 0)); _updateSnapText(); }

		if (FlxG.keys.pressed.LEFT)  { currentTime = Math.max(0, currentTime - SNAP_VALUES[snapIndex] * elapsed * 4); }
		if (FlxG.keys.pressed.RIGHT) { currentTime += SNAP_VALUES[snapIndex] * elapsed * 4; }

		if (FlxG.keys.justPressed.DELETE && selectedTrack >= 0 && selectedKeyframe >= 0)
			_deleteSelectedKeyframe();

		if (FlxG.keys.justPressed.INSERT && selectedTrack >= 0)
			_addKeyframeAtCursor();

		if (FlxG.keys.justPressed.F1) _showHelp();

		if (FlxG.keys.justPressed.UP   && selectedTrack > 0)                            { selectedTrack--; _rebuildTracks(); }
		if (FlxG.keys.justPressed.DOWN && selectedTrack < modData.tracks.length - 1)    { selectedTrack++; _rebuildTracks(); }
	}

	function _handleMouse()
	{
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;

		var inTimeline = (mx >= TIMELINE_X && mx <= TIMELINE_X + TIMELINE_W &&
		                  my >= TIMELINE_Y && my <= TIMELINE_Y + TIMELINE_H);

		if (inTimeline)
		{
			var localX = mx - TIMELINE_X + timelineScrollX;
			hoveringTime = _snapTime(localX / (PIXELS_PER_BEAT * timelineZoom));

			cursorLine.x = TIMELINE_X + (hoveringTime * PIXELS_PER_BEAT * timelineZoom) - timelineScrollX;
			cursorLine.visible = true;

			hoveringTrack = Std.int((my - TIMELINE_Y - HEADER_HEIGHT + timelineScrollY) / TRACK_HEIGHT);
			if (hoveringTrack < 0 || hoveringTrack >= modData.tracks.length) hoveringTrack = -1;

			if (FlxG.mouse.justPressed)
			{
				if (FlxG.mouse.y < TIMELINE_Y + HEADER_HEIGHT)
				{
					currentTime = hoveringTime;
					isDragging = true;
					dragStartX = mx;
					dragStartTime = currentTime;
				}
				else if (hoveringTrack >= 0)
				{
					if (FlxG.keys.pressed.SHIFT)
					{
						_addKeyframe(hoveringTrack, hoveringTime);
					}
					else
					{
						selectedTrack = hoveringTrack;
						selectedKeyframe = _findKeyframeAt(hoveringTrack, hoveringTime);
						_rebuildTracks();
						_updatePropertyPanel();
					}
				}
			}

			if (FlxG.mouse.pressed && isDragging)
			{
				var delta = (mx - dragStartX) / (PIXELS_PER_BEAT * timelineZoom);
				currentTime = Math.max(0, dragStartTime + delta);
			}

			if (FlxG.mouse.justReleased) isDragging = false;

			if (FlxG.mouse.justPressedMiddle)
			{
				dragStartX = mx;
			}

			if (FlxG.mouse.pressedMiddle)
			{
				timelineScrollX = Math.max(0, timelineScrollX - (mx - dragStartX));
				dragStartX = mx;
				_rebuildBeatLines();
				_rebuildTracks();
			}

			var wheel = FlxG.mouse.wheel;
			if (wheel != 0)
			{
				if (FlxG.keys.pressed.CONTROL)
				{
					_changeZoom(wheel > 0 ? 1.1 : 0.9);
				}
				else if (FlxG.keys.pressed.SHIFT)
				{
					timelineScrollX = Math.max(0, timelineScrollX - wheel * 30);
					_rebuildBeatLines();
					_rebuildTracks();
				}
				else
				{
					timelineScrollY = Math.max(0, timelineScrollY - wheel * TRACK_HEIGHT);
					_rebuildTracks();
				}
			}
		}
		else
		{
			cursorLine.visible = false;
			hoveringTrack = -1;
		}

		_handleLeftPanelClick(mx, my);
	}

	function _handleLeftPanelClick(mx:Float, my:Float)
	{
		if (mx >= 0 && mx <= 238 && my >= 60 && my <= FlxG.height - 30 && FlxG.mouse.justPressed)
		{
			var idx = Std.int((my - TIMELINE_Y - HEADER_HEIGHT + timelineScrollY) / TRACK_HEIGHT);
			if (idx >= 0 && idx < modData.tracks.length)
			{
				selectedTrack = idx;
				selectedKeyframe = -1;
				_rebuildTracks();
				_updatePropertyPanel();
				setStatus('Selected track: ' + modData.tracks[idx].target + '.' + modData.tracks[idx].property);
			}
		}
	}

	function _updatePlayhead(elapsed:Float)
	{
		if (isPlaying)
		{
			var bps = modData.bpm / 60;
			currentTime += bps * elapsed;

			if (currentTime * PIXELS_PER_BEAT * timelineZoom - timelineScrollX > TIMELINE_W * 0.75)
			{
				timelineScrollX += 60;
				_rebuildBeatLines();
				_rebuildTracks();
			}
		}

		var px = TIMELINE_X + currentTime * PIXELS_PER_BEAT * timelineZoom - timelineScrollX;
		playheadLine.x = px;
		playheadLine.visible = (px >= TIMELINE_X && px <= TIMELINE_X + TIMELINE_W);
	}

	function _updateHUD()
	{
		var beat = currentTime;
		var secs = beat / (modData.bpm / 60);
		timeText.text = 'TIME: ${_fmt(secs)}s  BEAT: ${_fmt(beat)}';

		if (hoveringTrack >= 0)
		{
			infoText.text = 'Track: ' + modData.tracks[hoveringTrack].id +
				'\nHover time: ${_fmt(hoveringTime)} beats' +
				'\nKeyframes: ' + modData.tracks[hoveringTrack].keyframes.length +
				'\n\nSHIFT+Click to add keyframe\nClick to select keyframe\nDEL to delete\nINS to insert at cursor';
		}
		else
		{
			infoText.text = 'No track hovered.\n\nControls:\nSPACE: Play/Pause\nHOME/END: Jump\n+/-: Zoom\n[/]: Snap\nCTRL+Z/Y: Undo/Redo\nCTRL+S: Save';
		}
	}

	function _updatePropertyPanel()
	{
		if (selectedTrack < 0 || selectedTrack >= modData.tracks.length) return;

		var track = modData.tracks[selectedTrack];
		setStatus('Track: ' + track.id + ' | Keyframes: ' + track.keyframes.length);
	}

	function _addKeyframe(trackIdx:Int, time:Float, ?value:Dynamic)
	{
		if (trackIdx < 0 || trackIdx >= modData.tracks.length) return;

		_pushUndo();

		var track = modData.tracks[trackIdx];
		if (value == null) value = 0.0;

		var existing = _findKeyframeAt(trackIdx, time);
		if (existing >= 0)
		{
			track.keyframes[existing].value = value;
			setStatus('Updated keyframe at beat ' + _fmt(time));
		}
		else
		{
			track.keyframes.push({time: time, value: value});
			track.keyframes.sort(function(a, b) return a.time < b.time ? -1 : 1);
			setStatus('Added keyframe at beat ' + _fmt(time) + ' on ' + track.id);
		}

		_rebuildTracks();
	}

	function _addKeyframeAtCursor()
	{
		if (selectedTrack < 0) return;
		_addKeyframe(selectedTrack, currentTime, 0.0);
	}

	function _deleteSelectedKeyframe()
	{
		if (selectedTrack < 0 || selectedKeyframe < 0) return;
		var track = modData.tracks[selectedTrack];
		if (selectedKeyframe >= track.keyframes.length) return;

		_pushUndo();
		track.keyframes.splice(selectedKeyframe, 1);
		selectedKeyframe = -1;
		setStatus('Deleted keyframe from ' + track.id);
		_rebuildTracks();
	}

	function _findKeyframeAt(trackIdx:Int, time:Float):Int
	{
		var track = modData.tracks[trackIdx];
		var threshold = 0.15 / timelineZoom;
		for (i in 0...track.keyframes.length)
			if (Math.abs(track.keyframes[i].time - time) <= threshold)
				return i;
		return -1;
	}

	function _snapTime(time:Float):Float
	{
		var snap = SNAP_VALUES[snapIndex];
		return Math.round(time / snap) * snap;
	}

	function _changeZoom(factor:Float)
	{
		timelineZoom = FlxMath.bound(timelineZoom * factor, MIN_ZOOM, MAX_ZOOM);
		zoomText.text = 'ZOOM: ' + Std.int(timelineZoom * 100) + '%';
		_rebuildBeatLines();
		_rebuildTracks();
	}

	function _updateSnapText()
	{
		var snaps = ['1', '1/2', '1/4', '1/8', '1/16'];
		snapText.text = 'SNAP: ' + snaps[snapIndex];
	}

	function _toBeat(time:Float):String return _fmt(time);
	function _fmt(v:Float):String return Std.string(Math.round(v * 100) / 100);
	function _getLastBeat():Float
	{
		var last:Float = 0;
		for (t in modData.tracks)
			for (kf in t.keyframes)
				if (kf.time > last) last = kf.time;
		return last + 4;
	}

	function _pushUndo()
	{
		undoStack.push(Json.stringify(modData));
		if (undoStack.length > MAX_UNDO) undoStack.shift();
		redoStack = [];
	}

	function undo()
	{
		if (undoStack.length == 0) { setStatus('Nothing to undo.'); return; }
		redoStack.push(Json.stringify(modData));
		modData = Json.parse(undoStack.pop());
		_rebuildTracks();
		setStatus('Undo. (' + undoStack.length + ' left)');
	}

	function redo()
	{
		if (redoStack.length == 0) { setStatus('Nothing to redo.'); return; }
		undoStack.push(Json.stringify(modData));
		modData = Json.parse(redoStack.pop());
		_rebuildTracks();
		setStatus('Redo. (' + redoStack.length + ' left)');
	}

	function save()
	{
		#if sys
		var path = 'modcharts/' + modData.song + '.json';
		if (!FileSystem.exists('modcharts')) FileSystem.createDirectory('modcharts');
		File.saveContent(path, Json.stringify(modData, null, '\t'));
		setStatus('Saved to ' + path);
		#end
	}

	function load()
	{
		#if sys
		var path = 'modcharts/' + modData.song + '.json';
		if (FileSystem.exists(path))
		{
			_pushUndo();
			modData = Json.parse(File.getContent(path));
			_rebuildTracks();
			setStatus('Loaded from ' + path);
		}
		else
			setStatus('File not found: ' + path);
		#end
	}

	function _showHelp()
	{
		setStatus('F1:Help | SPACE:Play | INS:AddKF | DEL:DeleteKF | SHIFT+Click:AddKF | +/-:Zoom | [/]:Snap | CTRL+S:Save | CTRL+Z:Undo | CTRL+Y:Redo | HOME/END:Jump | ESC:Exit');
	}

	function setStatus(msg:String)
	{
		statusText.text = msg;
	}

	override function destroy()
	{
		FlxG.mouse.visible = false;
		super.destroy();
	}
}
