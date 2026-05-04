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
#if sys
import sys.FileSystem;
import sys.io.File;
#end

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

typedef ModchartNoteEvent =
{
	var beat:Float;
	var lane:Int;
	var offsetX:Float;
	var offsetY:Float;
	var angle:Float;
	var alpha:Float;
	var scale:Float;
	var speed:Float;
}

typedef ModchartData =
{
	var version:String;
	var song:String;
	var bpm:Float;
	var tracks:Array<ModchartTrack>;
	var noteEvents:Array<ModchartNoteEvent>;
}

enum EditorMode
{
	TIMELINE;
	NOTE_EDITOR;
}

class ModchartEditorState extends MusicBeatState
{
	static inline var TIMELINE_X:Float      = 240;
	static inline var TIMELINE_Y:Float      = 58;
	static inline var TIMELINE_W:Float      = 820;
	static inline var TIMELINE_H:Float      = 460;
	static inline var TRACK_HEIGHT:Float    = 34;
	static inline var HEADER_HEIGHT:Float   = 28;
	static inline var PIXELS_PER_BEAT:Float = 80;
	static inline var MIN_ZOOM:Float        = 0.2;
	static inline var MAX_ZOOM:Float        = 5.0;
	static inline var MAX_UNDO:Int          = 50;

	static var SNAP_VALUES:Array<Float> = [1, 0.5, 0.25, 0.125, 0.0625];

	static inline var NOTE_W:Float  = 1280;
	static inline var NOTE_H:Float  = 720;
	static inline var NOTE_LANE_COUNT:Int = 8;

	var currentMode:EditorMode = TIMELINE;

	var camUI:FlxCamera;

	var modData:ModchartData;
	var selectedTrack:Int      = -1;
	var selectedKeyframe:Int   = -1;
	var selectedNoteEvent:Int  = -1;

	var timelineZoom:Float    = 1.0;
	var timelineScrollX:Float = 0;
	var timelineScrollY:Float = 0;
	var currentBeat:Float     = 0;
	var snapIndex:Int         = 2;
	var isPlaying:Bool        = false;
	var isDragging:Bool       = false;
	var dragStartX:Float      = 0;
	var dragStartBeat:Float   = 0;

	var undoStack:Array<String> = [];
	var redoStack:Array<String> = [];

	var trackSprites:FlxTypedGroup<FlxSprite>;
	var keyframeSprites:FlxTypedGroup<FlxSprite>;
	var beatLines:FlxTypedGroup<FlxSprite>;
	var noteEditorSprites:FlxTypedGroup<FlxSprite>;
	var noteHandles:FlxTypedGroup<FlxSprite>;

	var bg:FlxSprite;
	var topBar:FlxSprite;
	var accentLine:FlxSprite;
	var leftPanel:FlxSprite;
	var rightPanel:FlxSprite;
	var bottomBar:FlxSprite;
	var timelineArea:FlxSprite;
	var modeTabTimeline:FlxSprite;
	var modeTabNotes:FlxSprite;
	var modeTabTlText:FlxText;
	var modeTabNtText:FlxText;
	var noteEditorArea:FlxSprite;
	var noteEditorGrid:FlxSprite;
	var playheadLine:FlxSprite;
	var cursorLine:FlxSprite;
	var selDragHandle:FlxSprite;

	var statusText:FlxText;
	var timeText:FlxText;
	var snapText:FlxText;
	var zoomText:FlxText;
	var infoText:FlxText;
	var bpmText:FlxText;
	var modeText:FlxText;

	var hoveringTrack:Int  = -1;
	var hoveringBeat:Float = 0;

	var draggingNoteIdx:Int    = -1;
	var draggingNoteStartX:Float = 0;
	var draggingNoteStartY:Float = 0;
	var draggingNoteOffX:Float   = 0;
	var draggingNoteOffY:Float   = 0;

	#if mobile
	var touchStartX:Float  = 0;
	var touchStartY:Float  = 0;
	var touchMoved:Bool    = false;
	var pinchDist:Float    = 0;
	var lastPinchDist:Float = 0;
	#end

	static var _lastSongName:String = 'untitled';

	override function create()
	{
		super.create();

		FlxG.mouse.visible = true;

		camUI = new FlxCamera();
		FlxG.cameras.reset(camUI);
		FlxCamera.defaultCameras = [camUI];

		_initData();
		_buildUI();
		_buildTimeline();
		_buildNoteEditor();
		_rebuildTracks();
		_rebuildNoteEditor();

		#if mobile
		addTouchPad("NONE", "B");
		#end

		setStatus('Modchart Editor ready. F1 for help.');
	}

	function _initData()
	{
		modData = {
			version: '1.1',
			song: _lastSongName,
			bpm: Conductor.bpm > 0 ? Conductor.bpm : 120,
			tracks: [],
			noteEvents: []
		};

		var defs:Array<{id:String, target:String, prop:String, col:Int}> = [
			{id:'bf_x',        target:'boyfriend', prop:'x',          col:0xFF4FC3F7},
			{id:'bf_y',        target:'boyfriend', prop:'y',          col:0xFF81D4FA},
			{id:'bf_alpha',    target:'boyfriend', prop:'alpha',      col:0xFFB3E5FC},
			{id:'bf_angle',    target:'boyfriend', prop:'angle',      col:0xFF29B6F6},
			{id:'dad_x',       target:'dad',       prop:'x',          col:0xFFF48FB1},
			{id:'dad_y',       target:'dad',       prop:'y',          col:0xFFF06292},
			{id:'dad_alpha',   target:'dad',       prop:'alpha',      col:0xFFEC407A},
			{id:'gf_alpha',    target:'gf',        prop:'alpha',      col:0xFFCE93D8},
			{id:'cam_zoom',    target:'camGame',   prop:'zoom',       col:0xFFA5D6A7},
			{id:'cam_x',       target:'camGame',   prop:'x',          col:0xFF66BB6A},
			{id:'cam_y',       target:'camGame',   prop:'y',          col:0xFF81C784},
			{id:'hud_alpha',   target:'camHUD',    prop:'alpha',      col:0xFFCE93D8},
			{id:'speed',       target:'playState', prop:'speed',      col:0xFFFFCC02},
			{id:'health_gain', target:'playState', prop:'healthGain', col:0xFFFF7043},
			{id:'scroll_angle',target:'playState', prop:'scrollAngle',col:0xFF80DEEA},
		];

		for (d in defs)
			modData.tracks.push({id:d.id, target:d.target, property:d.prop, color:d.col, keyframes:[]});

		for (lane in 0...NOTE_LANE_COUNT)
			modData.noteEvents.push({beat:0, lane:lane, offsetX:0, offsetY:0, angle:0, alpha:1, scale:1, speed:1});
	}

	function _buildUI()
	{
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF0A0A18);
		bg.scrollFactor.set();
		add(bg);

		topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 52, 0xFF14213D);
		topBar.scrollFactor.set();
		add(topBar);

		accentLine = new FlxSprite(0, 52).makeGraphic(FlxG.width, 2, 0xFF00D4FF);
		accentLine.scrollFactor.set();
		add(accentLine);

		leftPanel = new FlxSprite(0, 54).makeGraphic(238, FlxG.height - 54, 0xFF14213D);
		leftPanel.scrollFactor.set();
		add(leftPanel);

		var lBorder = new FlxSprite(238, 54).makeGraphic(2, FlxG.height - 54, 0xFF0F3460);
		lBorder.scrollFactor.set();
		add(lBorder);

		rightPanel = new FlxSprite(FlxG.width - 238, 54).makeGraphic(238, FlxG.height - 54, 0xFF14213D);
		rightPanel.scrollFactor.set();
		add(rightPanel);

		var rBorder = new FlxSprite(FlxG.width - 240, 54).makeGraphic(2, FlxG.height - 54, 0xFF0F3460);
		rBorder.scrollFactor.set();
		add(rBorder);

		bottomBar = new FlxSprite(240, FlxG.height - 28).makeGraphic(FlxG.width - 480, 28, 0xFF14213D);
		bottomBar.scrollFactor.set();
		add(bottomBar);

		var bBorder = new FlxSprite(240, FlxG.height - 30).makeGraphic(FlxG.width - 480, 2, 0xFF0F3460);
		bBorder.scrollFactor.set();
		add(bBorder);

		var title = new FlxText(10, 15, 0, 'MODCHART EDITOR', 13);
		title.setFormat('VCR OSD Mono', 13, 0xFF00D4FF, LEFT);
		title.scrollFactor.set();
		add(title);

		bpmText = new FlxText(185, 15, 0, 'BPM: ${modData.bpm}', 12);
		bpmText.setFormat('VCR OSD Mono', 12, 0xFFFFCC02, LEFT);
		bpmText.scrollFactor.set();
		add(bpmText);

		modeText = new FlxText(FlxG.width - 200, 15, 190, 'MODE: TIMELINE', 12);
		modeText.setFormat('VCR OSD Mono', 12, 0xFF00D4FF, RIGHT);
		modeText.scrollFactor.set();
		add(modeText);

		timeText = new FlxText(FlxG.width - 420, 15, 210, 'BEAT: 0.00', 12);
		timeText.setFormat('VCR OSD Mono', 12, 0xFF78909C, RIGHT);
		timeText.scrollFactor.set();
		add(timeText);

		snapText = new FlxText(FlxG.width - 620, 15, 0, 'SNAP: 1/4', 12);
		snapText.setFormat('VCR OSD Mono', 12, 0xFF546E7A, LEFT);
		snapText.scrollFactor.set();
		add(snapText);

		zoomText = new FlxText(FlxG.width - 750, 15, 0, 'ZOOM: 100%', 12);
		zoomText.setFormat('VCR OSD Mono', 12, 0xFF546E7A, LEFT);
		zoomText.scrollFactor.set();
		add(zoomText);

		_buildTopButtons();

		statusText = new FlxText(242, FlxG.height - 22, 0, '', 10);
		statusText.setFormat('VCR OSD Mono', 10, 0xFF546E7A, LEFT);
		statusText.scrollFactor.set();
		add(statusText);

		infoText = new FlxText(6, FlxG.height - 220, 226, '', 9);
		infoText.setFormat('VCR OSD Mono', 9, 0xFF37474F, LEFT);
		infoText.wordWrap = true;
		infoText.scrollFactor.set();
		add(infoText);

		_buildLeftPanel();
		_buildRightPanel();
		_buildModeTabs();
	}

	function _buildTopButtons()
	{
		var btns = [
			{l:'SAVE', x:300}, {l:'LOAD', x:350}, {l:'NEW', x:400},
			{l:'UNDO', x:460}, {l:'REDO', x:510},
			{l:'PLAY', x:570}, {l:'STOP', x:620},
		];
		for (b in btns)
		{
			var bg2 = new FlxSprite(b.x, 12).makeGraphic(44, 26, 0xFF0F3460);
			bg2.scrollFactor.set();
			add(bg2);
			var t = new FlxText(b.x, 18, 44, b.l, 9);
			t.setFormat('VCR OSD Mono', 9, 0xFF00D4FF, CENTER);
			t.scrollFactor.set();
			add(t);
		}
	}

	function _buildModeTabs()
	{
		modeTabTimeline = new FlxSprite(240, 54).makeGraphic(100, 24, 0xFF00D4FF);
		modeTabTimeline.scrollFactor.set();
		add(modeTabTimeline);
		modeTabTlText = new FlxText(240, 57, 100, 'TIMELINE', 10);
		modeTabTlText.setFormat('VCR OSD Mono', 10, 0xFF0A0A18, CENTER);
		modeTabTlText.scrollFactor.set();
		add(modeTabTlText);

		modeTabNotes = new FlxSprite(342, 54).makeGraphic(100, 24, 0xFF0F3460);
		modeTabNotes.scrollFactor.set();
		add(modeTabNotes);
		modeTabNtText = new FlxText(342, 57, 100, 'NOTE POS', 10);
		modeTabNtText.setFormat('VCR OSD Mono', 10, 0xFF78909C, CENTER);
		modeTabNtText.scrollFactor.set();
		add(modeTabNtText);
	}

	function _buildLeftPanel()
	{
		var hdr = new FlxText(6, 62, 226, 'TRACKS  (${modData.tracks.length})', 10);
		hdr.setFormat('VCR OSD Mono', 10, 0xFF00D4FF, LEFT);
		hdr.scrollFactor.set();
		add(hdr);

		var addBg = new FlxSprite(188, 60).makeGraphic(46, 18, 0xFF1B5E20);
		addBg.scrollFactor.set();
		add(addBg);
		var addT = new FlxText(188, 63, 46, '+ ADD', 8);
		addT.setFormat('VCR OSD Mono', 8, 0xFF69F0AE, CENTER);
		addT.scrollFactor.set();
		add(addT);
	}

	function _buildRightPanel()
	{
		var px:Float = FlxG.width - 234;

		var hdr = new FlxText(px, 62, 228, 'PROPERTIES', 10);
		hdr.setFormat('VCR OSD Mono', 10, 0xFF00D4FF, LEFT);
		hdr.scrollFactor.set();
		add(hdr);

		var props = ['Target', 'Property', 'Value', 'Duration', 'Ease', 'Tag'];
		for (i in 0...props.length)
		{
			var lbl = new FlxText(px, 84 + i * 40, 110, props[i] + ':', 9);
			lbl.setFormat('VCR OSD Mono', 9, 0xFF546E7A, LEFT);
			lbl.scrollFactor.set();
			add(lbl);

			var iBg = new FlxSprite(px - 1, 96 + i * 40).makeGraphic(228, 22, 0xFF0F3460);
			iBg.scrollFactor.set();
			add(iBg);
			var iT = new FlxText(px + 3, 99 + i * 40, 222, '-', 9);
			iT.setFormat('VCR OSD Mono', 9, 0xFFECEFF1, LEFT);
			iT.scrollFactor.set();
			add(iT);
		}

		var applyBg = new FlxSprite(px - 1, 334).makeGraphic(228, 24, 0xFF1A237E);
		applyBg.scrollFactor.set();
		add(applyBg);
		var applyT = new FlxText(px - 1, 338, 228, 'APPLY KEYFRAME', 9);
		applyT.setFormat('VCR OSD Mono', 9, 0xFF82B1FF, CENTER);
		applyT.scrollFactor.set();
		add(applyT);

		var delBg = new FlxSprite(px - 1, 362).makeGraphic(110, 22, 0xFF4A1010);
		delBg.scrollFactor.set();
		add(delBg);
		var delT = new FlxText(px - 1, 365, 110, 'DELETE KF', 9);
		delT.setFormat('VCR OSD Mono', 9, 0xFFEF9A9A, CENTER);
		delT.scrollFactor.set();
		add(delT);

		var clrBg = new FlxSprite(px + 113, 362).makeGraphic(114, 22, 0xFF4A3500);
		clrBg.scrollFactor.set();
		add(clrBg);
		var clrT = new FlxText(px + 113, 365, 114, 'CLEAR TRACK', 9);
		clrT.setFormat('VCR OSD Mono', 9, 0xFFFFCC02, CENTER);
		clrT.scrollFactor.set();
		add(clrT);

		var noteHdr = new FlxText(px, 398, 228, 'NOTE EVENT', 10);
		noteHdr.setFormat('VCR OSD Mono', 10, 0xFF00D4FF, LEFT);
		noteHdr.scrollFactor.set();
		add(noteHdr);

		var noteProps = ['OffsetX', 'OffsetY', 'Angle', 'Alpha', 'Scale', 'Speed'];
		for (i in 0...noteProps.length)
		{
			var lbl2 = new FlxText(px, 416 + i * 28, 110, noteProps[i] + ':', 9);
			lbl2.setFormat('VCR OSD Mono', 9, 0xFF546E7A, LEFT);
			lbl2.scrollFactor.set();
			add(lbl2);
			var iB2 = new FlxSprite(px + 80, 414 + i * 28).makeGraphic(146, 20, 0xFF0F3460);
			iB2.scrollFactor.set();
			add(iB2);
			var iT2 = new FlxText(px + 83, 416 + i * 28, 140, '0', 9);
			iT2.setFormat('VCR OSD Mono', 9, 0xFFECEFF1, LEFT);
			iT2.scrollFactor.set();
			add(iT2);
		}
	}

	function _buildTimeline()
	{
		timelineArea = new FlxSprite(TIMELINE_X, TIMELINE_Y + 24).makeGraphic(
			Std.int(TIMELINE_W), Std.int(TIMELINE_H), 0xFF0E0E1C);
		timelineArea.scrollFactor.set();
		add(timelineArea);

		var tlBorder = new FlxSprite(TIMELINE_X - 1, TIMELINE_Y + 23).makeGraphic(
			Std.int(TIMELINE_W) + 2, Std.int(TIMELINE_H) + 2, 0xFF0F3460);
		tlBorder.scrollFactor.set();
		insert(members.indexOf(timelineArea), tlBorder);

		beatLines    = new FlxTypedGroup<FlxSprite>();
		trackSprites = new FlxTypedGroup<FlxSprite>();
		keyframeSprites = new FlxTypedGroup<FlxSprite>();
		add(beatLines);
		add(trackSprites);
		add(keyframeSprites);

		cursorLine = new FlxSprite(TIMELINE_X, TIMELINE_Y + 24).makeGraphic(2, Std.int(TIMELINE_H), 0x6600D4FF);
		cursorLine.visible = false;
		cursorLine.scrollFactor.set();
		add(cursorLine);

		playheadLine = new FlxSprite(TIMELINE_X, TIMELINE_Y + 24).makeGraphic(2, Std.int(TIMELINE_H) + 24, 0xFFFFCC02);
		playheadLine.scrollFactor.set();
		add(playheadLine);

		_rebuildBeatLines();
	}

	function _buildNoteEditor()
	{
		noteEditorArea = new FlxSprite(TIMELINE_X, TIMELINE_Y + 24).makeGraphic(
			Std.int(TIMELINE_W), Std.int(TIMELINE_H), 0xFF0E1020);
		noteEditorArea.visible = false;
		noteEditorArea.scrollFactor.set();
		add(noteEditorArea);

		noteEditorGrid = new FlxSprite(TIMELINE_X, TIMELINE_Y + 24).makeGraphic(
			Std.int(TIMELINE_W), Std.int(TIMELINE_H), FlxColor.TRANSPARENT);
		noteEditorGrid.visible = false;
		noteEditorGrid.scrollFactor.set();
		add(noteEditorGrid);

		noteEditorSprites = new FlxTypedGroup<FlxSprite>();
		noteHandles = new FlxTypedGroup<FlxSprite>();
		add(noteEditorSprites);
		add(noteHandles);
	}

	function _rebuildBeatLines()
	{
		beatLines.clear();

		var headerY = TIMELINE_Y + 24;
		var totalBeats:Int = 128;
		for (b in 0...totalBeats)
		{
			var x = TIMELINE_X + b * PIXELS_PER_BEAT * timelineZoom - timelineScrollX;
			if (x < TIMELINE_X || x > TIMELINE_X + TIMELINE_W) continue;

			var isMeasure = (b % 4 == 0);
			var line = new FlxSprite(x, headerY).makeGraphic(1, Std.int(TIMELINE_H),
				isMeasure ? 0x44FFFFFF : 0x18FFFFFF);
			line.scrollFactor.set();
			beatLines.add(line);

			if (isMeasure)
			{
				var n = new FlxText(x + 2, headerY + 2, 0, Std.string(b), 8);
				n.setFormat('VCR OSD Mono', 8, isMeasure ? 0xFF546E7A : 0xFF263238, LEFT);
				n.scrollFactor.set();
				beatLines.add(n);
			}
		}
	}

	function _rebuildTracks()
	{
		trackSprites.clear();
		keyframeSprites.clear();

		var headerY = TIMELINE_Y + 24;

		for (i in 0...modData.tracks.length)
		{
			var track = modData.tracks[i];
			var ty    = headerY + HEADER_HEIGHT + i * TRACK_HEIGHT - timelineScrollY;
			if (ty + TRACK_HEIGHT < headerY || ty > headerY + TIMELINE_H) continue;

			var isSel = (i == selectedTrack);
			var rowColor = isSel ? 0xFF0F3460 : (i % 2 == 0 ? 0xFF111120 : 0xFF0E0E1C);
			var row = new FlxSprite(TIMELINE_X, ty).makeGraphic(Std.int(TIMELINE_W), Std.int(TRACK_HEIGHT) - 1, rowColor);
			row.scrollFactor.set();
			trackSprites.add(row);

			var tag = new FlxSprite(TIMELINE_X, ty).makeGraphic(3, Std.int(TRACK_HEIGHT) - 1, track.color);
			tag.scrollFactor.set();
			trackSprites.add(tag);

			for (j in 0...track.keyframes.length)
			{
				var kf = track.keyframes[j];
				var kx = TIMELINE_X + kf.time * PIXELS_PER_BEAT * timelineZoom - timelineScrollX;
				if (kx < TIMELINE_X || kx > TIMELINE_X + TIMELINE_W) continue;

				var isSelKF = (isSel && j == selectedKeyframe);
				var dia = new FlxSprite(kx - 6, ty + TRACK_HEIGHT / 2 - 6).makeGraphic(12, 12, FlxColor.TRANSPARENT);
				_drawDiamond(dia, isSelKF ? 0xFFFFFFFF : track.color);
				dia.scrollFactor.set();
				keyframeSprites.add(dia);
			}
		}

		for (i in 0...modData.tracks.length)
		{
			var track = modData.tracks[i];
			var ty    = headerY + HEADER_HEIGHT + i * TRACK_HEIGHT - timelineScrollY;
			if (ty + TRACK_HEIGHT < headerY || ty > headerY + TIMELINE_H) continue;

			var lbl = new FlxText(7, ty + 3, 225, track.target + '.' + track.property, 9);
			lbl.setFormat('VCR OSD Mono', 9, FlxColor.fromInt(track.color), LEFT);
			lbl.scrollFactor.set();
			trackSprites.add(lbl);

			var kc = new FlxText(200, ty + 3, 36, Std.string(track.keyframes.length), 9);
			kc.setFormat('VCR OSD Mono', 9, 0xFF263238, RIGHT);
			kc.scrollFactor.set();
			trackSprites.add(kc);
		}
	}

	function _rebuildNoteEditor()
	{
		noteEditorSprites.clear();
		noteHandles.clear();

		if (currentMode != NOTE_EDITOR) return;

		var areaX = TIMELINE_X;
		var areaY = TIMELINE_Y + 24;
		var laneW = TIMELINE_W / NOTE_LANE_COUNT;

		for (lane in 0...NOTE_LANE_COUNT)
		{
			var lx = areaX + lane * laneW;
			var col = (lane % 2 == 0) ? 0xFF111120 : 0xFF0E0E1C;
			var bg2 = new FlxSprite(lx, areaY).makeGraphic(Std.int(laneW) - 1, Std.int(TIMELINE_H), col);
			bg2.scrollFactor.set();
			noteEditorSprites.add(bg2);

			var laneColors:Array<Int> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F,
			                              0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
			var lbl = new FlxText(lx + 2, areaY + 2, Std.int(laneW) - 4, 'L' + lane, 8);
			lbl.setFormat('VCR OSD Mono', 8, FlxColor.fromInt(laneColors[lane % 8]), CENTER);
			lbl.scrollFactor.set();
			noteEditorSprites.add(lbl);
		}

		for (i in 0...modData.noteEvents.length)
		{
			var ev = modData.noteEvents[i];
			if (ev.lane < 0 || ev.lane >= NOTE_LANE_COUNT) continue;

			var laneW2 = TIMELINE_W / NOTE_LANE_COUNT;
			var baseLX = areaX + ev.lane * laneW2;
			var centerX = baseLX + laneW2 / 2;
			var centerY = areaY + TIMELINE_H / 2;

			var nx = centerX + ev.offsetX * 0.5 - 14;
			var ny = centerY + ev.offsetY * 0.5 - 14;

			var noteColors:Array<Int> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F,
			                              0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
			var nc = noteColors[ev.lane % 8];

			var shadow = new FlxSprite(nx + 2, ny + 2).makeGraphic(28, 28, 0x44000000);
			shadow.scrollFactor.set();
			noteEditorSprites.add(shadow);

			var note = new FlxSprite(nx, ny).makeGraphic(28, 28, nc);
			note.angle  = ev.angle;
			note.alpha  = ev.alpha;
			note.scale.set(ev.scale, ev.scale);
			note.scrollFactor.set();
			noteEditorSprites.add(note);

			var isSel = (i == selectedNoteEvent);
			var handle = new FlxSprite(nx + 10, ny + 10).makeGraphic(8, 8, isSel ? 0xFFFFFFFF : 0x88FFFFFF);
			handle.scrollFactor.set();
			noteHandles.add(handle);

			if (isSel)
			{
				var outline = new FlxSprite(nx - 2, ny - 2).makeGraphic(32, 32, FlxColor.TRANSPARENT);
				_drawOutline(outline, 0xFF00D4FF);
				outline.scrollFactor.set();
				noteEditorSprites.add(outline);
			}

			if (ev.offsetX != 0 || ev.offsetY != 0)
			{
				var originX = centerX - 5;
				var originY = centerY - 5;
				var arrow = new FlxSprite(originX, originY).makeGraphic(10, 10, 0x6600D4FF);
				arrow.scrollFactor.set();
				noteEditorSprites.add(arrow);
			}
		}
	}

	function _drawDiamond(spr:FlxSprite, color:Int)
	{
		var p = spr.pixels;
		var c = FlxColor.fromInt(color);
		var cx = 6; var cy = 6;
		for (dx in -5...6) for (dy in -5...6)
			if (Math.abs(dx) + Math.abs(dy) <= 5)
				p.setPixel32(cx + dx, cy + dy, c);
		spr.loadGraphic(flixel.graphics.FlxGraphic.fromBitmapData(p));
	}

	function _drawOutline(spr:FlxSprite, color:Int)
	{
		var p = spr.pixels;
		var c = FlxColor.fromInt(color);
		for (x in 0...32)
		{
			p.setPixel32(x, 0, c);
			p.setPixel32(x, 31, c);
		}
		for (y in 0...32)
		{
			p.setPixel32(0, y, c);
			p.setPixel32(31, y, c);
		}
		spr.loadGraphic(flixel.graphics.FlxGraphic.fromBitmapData(p));
	}

	function _setMode(mode:EditorMode)
	{
		currentMode = mode;

		var isTL = (mode == TIMELINE);
		timelineArea.visible    = isTL;
		beatLines.visible       = isTL;
		trackSprites.visible    = isTL;
		keyframeSprites.visible = isTL;
		cursorLine.visible      = false;
		playheadLine.visible    = isTL;

		noteEditorArea.visible  = !isTL;
		noteEditorGrid.visible  = !isTL;
		noteEditorSprites.visible = !isTL;
		noteHandles.visible     = !isTL;

		modeTabTimeline.color = isTL  ? 0xFF00D4FF : 0xFF0F3460;
		modeTabNotes.color    = !isTL ? 0xFF00D4FF : 0xFF0F3460;
		modeTabTlText.color   = isTL  ? 0xFF0A0A18 : 0xFF78909C;
		modeTabNtText.color   = !isTL ? 0xFF0A0A18 : 0xFF78909C;

		modeText.text = 'MODE: ' + (isTL ? 'TIMELINE' : 'NOTE POS');

		if (!isTL) _rebuildNoteEditor();

		setStatus(isTL ? 'Timeline mode.' : 'Note Position Editor — drag notes to offset them.');
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		_handleKeyboard(elapsed);
		_handleMouse();

		#if mobile
		_handleTouch();
		#end

		_updatePlayhead(elapsed);
		_updateHUD();
	}

	function _handleKeyboard(elapsed:Float)
	{
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.mouse.visible = false;
			#if mobile
			removeTouchPad();
			#end
			MusicBeatState.switchState(new editors.MasterEditorMenu());
			return;
		}

		if (FlxG.keys.justPressed.TAB)
		{
			_setMode(currentMode == TIMELINE ? NOTE_EDITOR : TIMELINE);
			return;
		}

		if (FlxG.keys.pressed.CONTROL)
		{
			if (FlxG.keys.justPressed.Z) { undo(); return; }
			if (FlxG.keys.justPressed.Y) { redo(); return; }
			if (FlxG.keys.justPressed.S) { save(); return; }
			if (FlxG.keys.justPressed.O) { load(); return; }
		}

		if (FlxG.keys.justPressed.SPACE)
		{
			isPlaying = !isPlaying;
			setStatus(isPlaying ? 'Playing...' : 'Paused at beat ' + _fmt(currentBeat));
		}

		if (FlxG.keys.justPressed.HOME)  { currentBeat = 0; timelineScrollX = 0; _rebuildBeatLines(); _rebuildTracks(); }
		if (FlxG.keys.justPressed.END)   { currentBeat = _getLastBeat(); }

		if (FlxG.keys.justPressed.EQUALS || FlxG.keys.justPressed.NUMPADPLUS)  _changeZoom(1.2);
		if (FlxG.keys.justPressed.MINUS  || FlxG.keys.justPressed.NUMPADMINUS) _changeZoom(0.83);

		if (FlxG.keys.justPressed.LBRACKET)  { snapIndex = Std.int(Math.min(snapIndex + 1, SNAP_VALUES.length - 1)); _updateSnapText(); }
		if (FlxG.keys.justPressed.RBRACKET)  { snapIndex = Std.int(Math.max(snapIndex - 1, 0)); _updateSnapText(); }

		if (currentMode == TIMELINE)
		{
			if (FlxG.keys.pressed.LEFT)   currentBeat = Math.max(0, currentBeat - SNAP_VALUES[snapIndex] * elapsed * 4);
			if (FlxG.keys.pressed.RIGHT)  currentBeat += SNAP_VALUES[snapIndex] * elapsed * 4;
			if (FlxG.keys.justPressed.DELETE && selectedTrack >= 0 && selectedKeyframe >= 0) _deleteSelectedKeyframe();
			if (FlxG.keys.justPressed.INSERT && selectedTrack >= 0) _addKeyframeAtCursor();
			if (FlxG.keys.justPressed.UP   && selectedTrack > 0)                            { selectedTrack--; _rebuildTracks(); }
			if (FlxG.keys.justPressed.DOWN && selectedTrack < modData.tracks.length - 1)    { selectedTrack++; _rebuildTracks(); }
		}
		else
		{
			if (selectedNoteEvent >= 0 && selectedNoteEvent < modData.noteEvents.length)
			{
				var ev = modData.noteEvents[selectedNoteEvent];
				var step:Float = FlxG.keys.pressed.SHIFT ? 10 : 1;
				if (FlxG.keys.pressed.LEFT)   { _pushUndo(); ev.offsetX -= step; _rebuildNoteEditor(); }
				if (FlxG.keys.pressed.RIGHT)  { _pushUndo(); ev.offsetX += step; _rebuildNoteEditor(); }
				if (FlxG.keys.pressed.UP)     { _pushUndo(); ev.offsetY -= step; _rebuildNoteEditor(); }
				if (FlxG.keys.pressed.DOWN)   { _pushUndo(); ev.offsetY += step; _rebuildNoteEditor(); }
				if (FlxG.keys.justPressed.R)  { _pushUndo(); ev.offsetX = 0; ev.offsetY = 0; ev.angle = 0; ev.alpha = 1; ev.scale = 1; _rebuildNoteEditor(); setStatus('Reset note event #' + selectedNoteEvent); }
				if (FlxG.keys.justPressed.Q)  { _pushUndo(); ev.angle -= 15; _rebuildNoteEditor(); }
				if (FlxG.keys.justPressed.E)  { _pushUndo(); ev.angle += 15; _rebuildNoteEditor(); }
			}
		}

		if (FlxG.keys.justPressed.F1) _showHelp();
	}

	function _handleMouse()
	{
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		var areaY = TIMELINE_Y + 24;

		if (FlxG.mouse.justPressed)
		{
			if (my >= 54 && my <= 78 && mx >= 240 && mx <= 342) { _setMode(TIMELINE); return; }
			if (my >= 54 && my <= 78 && mx >= 342 && mx <= 442) { _setMode(NOTE_EDITOR); return; }
		}

		var inArea = (mx >= TIMELINE_X && mx <= TIMELINE_X + TIMELINE_W &&
		              my >= areaY && my <= areaY + TIMELINE_H);

		if (currentMode == TIMELINE)
		{
			if (inArea)
			{
				var localX = mx - TIMELINE_X + timelineScrollX;
				hoveringBeat = _snapTime(localX / (PIXELS_PER_BEAT * timelineZoom));

				cursorLine.x = TIMELINE_X + (hoveringBeat * PIXELS_PER_BEAT * timelineZoom) - timelineScrollX;
				cursorLine.visible = true;

				hoveringTrack = Std.int((my - areaY - HEADER_HEIGHT + timelineScrollY) / TRACK_HEIGHT);
				if (hoveringTrack < 0 || hoveringTrack >= modData.tracks.length) hoveringTrack = -1;

				if (FlxG.mouse.justPressed)
				{
					if (my < areaY + HEADER_HEIGHT)
					{
						currentBeat = hoveringBeat;
						isDragging = true;
						dragStartX = mx;
						dragStartBeat = currentBeat;
					}
					else if (hoveringTrack >= 0)
					{
						if (FlxG.keys.pressed.SHIFT)
							_addKeyframe(hoveringTrack, hoveringBeat);
						else
						{
							selectedTrack    = hoveringTrack;
							selectedKeyframe = _findKeyframeAt(hoveringTrack, hoveringBeat);
							_rebuildTracks();
						}
					}
				}

				if (FlxG.mouse.pressed && isDragging)
				{
					var delta = (mx - dragStartX) / (PIXELS_PER_BEAT * timelineZoom);
					currentBeat = Math.max(0, dragStartBeat + delta);
				}

				if (FlxG.mouse.justReleased) isDragging = false;

				if (FlxG.mouse.pressedMiddle)
				{
					timelineScrollX = Math.max(0, timelineScrollX - FlxG.mouse.deltaScreenX);
					_rebuildBeatLines();
					_rebuildTracks();
				}

				var w = FlxG.mouse.wheel;
				if (w != 0)
				{
					if (FlxG.keys.pressed.CONTROL)      _changeZoom(w > 0 ? 1.1 : 0.9);
					else if (FlxG.keys.pressed.SHIFT)   { timelineScrollX = Math.max(0, timelineScrollX - w * 28); _rebuildBeatLines(); _rebuildTracks(); }
					else                                 { timelineScrollY = Math.max(0, timelineScrollY - w * TRACK_HEIGHT); _rebuildTracks(); }
				}
			}
			else
			{
				cursorLine.visible = false;
				hoveringTrack = -1;
			}

			if (mx >= 0 && mx <= 238 && my >= 60 && FlxG.mouse.justPressed)
			{
				var idx = Std.int((my - areaY - HEADER_HEIGHT + timelineScrollY) / TRACK_HEIGHT);
				if (idx >= 0 && idx < modData.tracks.length)
				{
					selectedTrack    = idx;
					selectedKeyframe = -1;
					_rebuildTracks();
					setStatus('Track: ' + modData.tracks[idx].id);
				}
			}
		}
		else
		{
			if (inArea)
			{
				if (FlxG.mouse.justPressed)
				{
					var laneW = TIMELINE_W / NOTE_LANE_COUNT;
					for (i in 0...modData.noteEvents.length)
					{
						var ev  = modData.noteEvents[i];
						var lx  = TIMELINE_X + ev.lane * laneW + laneW / 2 + ev.offsetX * 0.5;
						var ly  = areaY + TIMELINE_H / 2 + ev.offsetY * 0.5;
						if (Math.abs(mx - lx) <= 18 && Math.abs(my - ly) <= 18)
						{
							selectedNoteEvent  = i;
							draggingNoteIdx    = i;
							draggingNoteStartX = mx;
							draggingNoteStartY = my;
							draggingNoteOffX   = ev.offsetX;
							draggingNoteOffY   = ev.offsetY;
							_rebuildNoteEditor();
							setStatus('Note lane ' + ev.lane + '  offset(' + _fmt(ev.offsetX) + ', ' + _fmt(ev.offsetY) + ')');
							break;
						}
					}
				}

				if (FlxG.mouse.pressed && draggingNoteIdx >= 0)
				{
					_pushUndo();
					var ev = modData.noteEvents[draggingNoteIdx];
					ev.offsetX = draggingNoteOffX + (mx - draggingNoteStartX) * 2;
					ev.offsetY = draggingNoteOffY + (my - draggingNoteStartY) * 2;
					_rebuildNoteEditor();
					setStatus('Lane ' + ev.lane + '  X: ' + _fmt(ev.offsetX) + '  Y: ' + _fmt(ev.offsetY));
				}

				if (FlxG.mouse.justReleased) draggingNoteIdx = -1;

				var w2 = FlxG.mouse.wheel;
				if (w2 != 0 && selectedNoteEvent >= 0)
				{
					_pushUndo();
					var ev = modData.noteEvents[selectedNoteEvent];
					if (FlxG.keys.pressed.SHIFT)      { ev.angle += w2 * 5; setStatus('Angle: ' + ev.angle); }
					else if (FlxG.keys.pressed.ALT)   { ev.scale = FlxMath.bound(ev.scale + w2 * 0.05, 0.1, 3); setStatus('Scale: ' + _fmt(ev.scale)); }
					else                               { ev.alpha = FlxMath.bound(ev.alpha + w2 * 0.05, 0, 1); setStatus('Alpha: ' + _fmt(ev.alpha)); }
					_rebuildNoteEditor();
				}
			}
		}
	}

	#if mobile
	function _handleTouch()
	{
		var touches = FlxG.touches.list;
		if (touches.length == 0) return;

		var t = touches[0];
		var areaY = TIMELINE_Y + 24;
		var inArea = (t.screenX >= TIMELINE_X && t.screenX <= TIMELINE_X + TIMELINE_W &&
		              t.screenY >= areaY && t.screenY <= areaY + TIMELINE_H);

		if (t.justPressed)
		{
			touchStartX = t.screenX;
			touchStartY = t.screenY;
			touchMoved  = false;
		}

		if (t.pressed && (Math.abs(t.screenX - touchStartX) > 8 || Math.abs(t.screenY - touchStartY) > 8))
			touchMoved = true;

		if (touches.length == 2 && currentMode == TIMELINE)
		{
			var t2 = touches[1];
			var d  = Math.sqrt(Math.pow(t.screenX - t2.screenX, 2) + Math.pow(t.screenY - t2.screenY, 2));
			if (lastPinchDist > 0)
				_changeZoom(d / lastPinchDist);
			lastPinchDist = d;
		}
		else lastPinchDist = 0;

		if (t.justReleased && !touchMoved && inArea)
		{
			if (currentMode == TIMELINE && t.screenY >= areaY + HEADER_HEIGHT)
			{
				var localX = t.screenX - TIMELINE_X + timelineScrollX;
				var beat   = _snapTime(localX / (PIXELS_PER_BEAT * timelineZoom));
				var track  = Std.int((t.screenY - areaY - HEADER_HEIGHT + timelineScrollY) / TRACK_HEIGHT);
				if (track >= 0 && track < modData.tracks.length)
				{
					selectedTrack = track;
					var kf = _findKeyframeAt(track, beat);
					if (kf >= 0) { selectedKeyframe = kf; }
					else          _addKeyframe(track, beat);
					_rebuildTracks();
				}
			}
			else if (currentMode == NOTE_EDITOR)
			{
				var laneW = TIMELINE_W / NOTE_LANE_COUNT;
				for (i in 0...modData.noteEvents.length)
				{
					var ev = modData.noteEvents[i];
					var lx = TIMELINE_X + ev.lane * laneW + laneW / 2 + ev.offsetX * 0.5;
					var ly = areaY + TIMELINE_H / 2 + ev.offsetY * 0.5;
					if (Math.abs(t.screenX - lx) <= 22 && Math.abs(t.screenY - ly) <= 22)
					{
						selectedNoteEvent = i;
						_rebuildNoteEditor();
						setStatus('Note lane ' + ev.lane + '  X:' + _fmt(ev.offsetX) + ' Y:' + _fmt(ev.offsetY));
						break;
					}
				}
			}
		}

		if (t.pressed && touchMoved && touches.length == 1)
		{
			if (currentMode == TIMELINE)
			{
				timelineScrollX = Math.max(0, timelineScrollX - (t.screenX - touchStartX) * 0.5);
				_rebuildBeatLines();
				_rebuildTracks();
			}
			else if (currentMode == NOTE_EDITOR && selectedNoteEvent >= 0)
			{
				_pushUndo();
				var ev = modData.noteEvents[selectedNoteEvent];
				ev.offsetX += (t.screenX - touchStartX) * 2;
				ev.offsetY += (t.screenY - touchStartY) * 2;
				_rebuildNoteEditor();
			}
			touchStartX = t.screenX;
			touchStartY = t.screenY;
		}

		if (touchPad != null && touchPad.buttonB.justPressed)
		{
			FlxG.mouse.visible = false;
			removeTouchPad();
			MusicBeatState.switchState(new editors.MasterEditorMenu());
		}
	}
	#end

	function _updatePlayhead(elapsed:Float)
	{
		if (isPlaying)
		{
			currentBeat += (modData.bpm / 60) * elapsed;
			if (currentBeat * PIXELS_PER_BEAT * timelineZoom - timelineScrollX > TIMELINE_W * 0.7)
			{
				timelineScrollX += 50;
				_rebuildBeatLines();
				_rebuildTracks();
			}
		}

		var px = TIMELINE_X + currentBeat * PIXELS_PER_BEAT * timelineZoom - timelineScrollX;
		playheadLine.x = px;
		playheadLine.visible = (px >= TIMELINE_X && px <= TIMELINE_X + TIMELINE_W) && currentMode == TIMELINE;
	}

	function _updateHUD()
	{
		var secs = currentBeat / (modData.bpm / 60);
		timeText.text = 'BEAT: ${_fmt(currentBeat)}  (${_fmt(secs)}s)';

		if (currentMode == TIMELINE && hoveringTrack >= 0)
		{
			var t = modData.tracks[hoveringTrack];
			infoText.text = 'ID: ' + t.id
				+ '\nTarget: ' + t.target
				+ '\nProp: ' + t.property
				+ '\nKFs: ' + t.keyframes.length
				+ '\n\nSHIFT+Click: add KF'
				+ '\nClick: select'
				+ '\nDEL: delete KF'
				+ '\nINS: insert at cursor'
				+ '\nCTRL+Z/Y: undo/redo';
		}
		else if (currentMode == NOTE_EDITOR && selectedNoteEvent >= 0)
		{
			var ev = modData.noteEvents[selectedNoteEvent];
			infoText.text = 'Lane: ' + ev.lane
				+ '\nOffX: ' + _fmt(ev.offsetX)
				+ '\nOffY: ' + _fmt(ev.offsetY)
				+ '\nAngle: ' + _fmt(ev.angle)
				+ '\nAlpha: ' + _fmt(ev.alpha)
				+ '\nScale: ' + _fmt(ev.scale)
				+ '\nSpeed: ' + _fmt(ev.speed)
				+ '\n\nDrag to move'
				+ '\nScroll: alpha'
				+ '\nSHIFT+Scroll: angle'
				+ '\nALT+Scroll: scale'
				+ '\nR: reset'
				+ '\nQ/E: rotate ±15';
		}
		else
		{
			infoText.text = 'TAB: toggle mode\nSPACE: play/pause\n+/-: zoom\n[/]: snap\nHOME/END: jump\nCTRL+S: save\nF1: help\nESC: exit';
		}
	}

	function _addKeyframe(trackIdx:Int, time:Float, ?value:Dynamic)
	{
		if (trackIdx < 0 || trackIdx >= modData.tracks.length) return;
		_pushUndo();
		var track = modData.tracks[trackIdx];
		if (value == null) value = 0.0;
		var existing = _findKeyframeAt(trackIdx, time);
		if (existing >= 0) { track.keyframes[existing].value = value; setStatus('Updated KF at beat ' + _fmt(time)); }
		else
		{
			track.keyframes.push({time: time, value: value});
			track.keyframes.sort(function(a:ModchartKeyframe, b:ModchartKeyframe) return a.time < b.time ? -1 : 1);
			setStatus('Added KF at beat ' + _fmt(time) + ' on ' + track.id);
		}
		_rebuildTracks();
	}

	function _addKeyframeAtCursor()
	{
		if (selectedTrack < 0) return;
		_addKeyframe(selectedTrack, currentBeat, 0.0);
	}

	function _deleteSelectedKeyframe()
	{
		if (selectedTrack < 0 || selectedKeyframe < 0) return;
		var track = modData.tracks[selectedTrack];
		if (selectedKeyframe >= track.keyframes.length) return;
		_pushUndo();
		track.keyframes.splice(selectedKeyframe, 1);
		selectedKeyframe = -1;
		setStatus('Deleted KF from ' + track.id);
		_rebuildTracks();
	}

	function _findKeyframeAt(trackIdx:Int, time:Float):Int
	{
		var track = modData.tracks[trackIdx];
		var threshold = 0.2 / timelineZoom;
		for (i in 0...track.keyframes.length)
			if (Math.abs(track.keyframes[i].time - time) <= threshold) return i;
		return -1;
	}

	function _snapTime(time:Float):Float
	{
		var s = SNAP_VALUES[snapIndex];
		return Math.max(0, Math.round(time / s) * s);
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

	function _fmt(v:Float):String  return Std.string(Math.round(v * 100) / 100);
	function _getLastBeat():Float
	{
		var last:Float = 0;
		for (t in modData.tracks) for (kf in t.keyframes) if (kf.time > last) last = kf.time;
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
		_rebuildNoteEditor();
		setStatus('Undo (' + undoStack.length + ' left)');
	}

	function redo()
	{
		if (redoStack.length == 0) { setStatus('Nothing to redo.'); return; }
		undoStack.push(Json.stringify(modData));
		modData = Json.parse(redoStack.pop());
		_rebuildTracks();
		_rebuildNoteEditor();
		setStatus('Redo (' + redoStack.length + ' left)');
	}

	function save()
	{
		#if sys
		var dir = 'modcharts';
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		var path = dir + '/' + modData.song + '.json';
		File.saveContent(path, Json.stringify(modData, null, '\t'));
		setStatus('Saved → ' + path);
		#else
		setStatus('Save not supported on this platform.');
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
			_rebuildNoteEditor();
			setStatus('Loaded ← ' + path);
		}
		else setStatus('Not found: ' + path);
		#end
	}

	function _showHelp()
	{
		setStatus('TAB:Mode | SPACE:Play | INS:KF | DEL:KF | SHIFT+Click:AddKF | +/-:Zoom | [/]:Snap | CTRL+S:Save | Z/Y:Undo/Redo | R:ResetNote | Q/E:Rotate | Scroll:Alpha | ESC:Exit');
	}

	function setStatus(msg:String)
	{
		statusText.text = msg;
	}

	override function destroy()
	{
		FlxG.mouse.visible = false;
		#if mobile
		removeTouchPad();
		#end
		super.destroy();
	}
}
