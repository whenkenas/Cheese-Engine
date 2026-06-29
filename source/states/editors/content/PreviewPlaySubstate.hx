package states.editors.content;

import backend.StageData;
import backend.Song;

import objects.Character;
import objects.Note.EventNote;
import objects.*;
import states.stages.*;
import states.stages.objects.*;
import flixel.FlxObject;

#if LUA_ALLOWED
import psychlua.*;
import psychlua.LuaUtils;
import psychlua.HScript;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript.HScriptInfos;
import crowplexus.iris.Iris;
#end

#if sys
import sys.FileSystem;
#end

class PreviewPlaySubstate extends MusicBeatSubstate
{
	// Preview viewport dimensions — same as screenshot preview
	public static inline var PREVIEW_W:Int = 256;
	public static inline var PREVIEW_H:Int = 144;
	public static inline var BORDER:Int    = 5;

	// The FlxCamera that renders the game world into the preview region
	var previewCam:FlxCamera;

	// Fake PlayState fields that stages/scripts need
	public var boyfriend:Character       = null;
	public var dad:Character             = null;
	public var gf:Character              = null;
	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public var extraCharacters:Array<Character>          = [];
	public var extraCharacterGroups:Array<FlxSpriteGroup> = [];

	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;
	public var camOther:FlxCamera;
	public var camFollow:FlxObject;

	public var defaultCamZoom:Float      = 1.05;
	public var cameraSpeed:Float         = 1;
	public var camZooming:Bool           = false;
	public var camZoomingMult:Float      = 1;
	public var camZoomingDecay:Float     = 1;
	public var gfSpeed:Int               = 1;

	public var BF_X:Float  = 770;
	public var BF_Y:Float  = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float  = 400;
	public var GF_Y:Float  = 130;

	public var boyfriendCameraOffset:Array<Float> = [0, 0];
	public var opponentCameraOffset:Array<Float>  = [0, 0];
	public var girlfriendCameraOffset:Array<Float> = [0, 0];

	public var isCameraOnForcedPos:Bool           = false;
	public var targetCameraEventInstant:Bool      = false;
	public var targetCameraEventTween:FlxTween    = null;
	public var cameraFollowPosTween:FlxTween      = null;

	public var paused:Bool        = false;
	public var inCutscene:Bool    = false;
	public var canPause:Bool      = false;
	public var startingSong:Bool  = true;
	public var endingSong:Bool    = false;
	public var generatedMusic:Bool = true;
	public var songName:String    = '';
	public var playbackRate:Float = 1;
	public var variables:Map<String, Dynamic> = new Map();

	// Scripting
	#if LUA_ALLOWED
	public var luaArray:Array<FunkinLua> = [];
	#end
	#if HSCRIPT_ALLOWED
	public var hscriptArray:Array<HScript> = [];
	#end
	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	var luaDebugGroup:FlxTypedGroup<psychlua.DebugLuaText>;
	#end

	public var stages:Array<BaseStage> = [];
	var previewEventNotes:Array<EventNote> = [];

	// Border overlay (OpenFL layer, not Flixel)
	var borderSprite:openfl.display.Sprite;

	var _camPosX:Float  = 0;
	var _camPosY:Float  = 0;
	var _camScaleX:Float = 1;
	var _camScaleY:Float = 1;

	// Previous PlayState.instance so we restore it on close
	var _prevPlayStateInstance:states.PlayState;

	// BPM change tracking for Conductor sync
	var lastBeatHit:Int  = -1;
	var lastSectionHit:Int = -1;

	public function new()
	{
		super();
	}

	override function create()
	{
		// Save and hijack PlayState.instance so BaseStage.get_game() works
		_prevPlayStateInstance = states.PlayState.instance;
		states.PlayState.instance = cast this;

		// --- Cameras ---
		// previewCam renders into a small viewport at bottom-left
		previewCam = new FlxCamera();
		previewCam.bgColor = FlxColor.BLACK;

		var scaleX:Float = PREVIEW_W / FlxG.width;
		var scaleY:Float = PREVIEW_H / FlxG.height;
		_camScaleX = scaleX;
		_camScaleY = scaleY;
		@:privateAccess
		{
			previewCam.flashSprite.scaleX = scaleX;
			previewCam.flashSprite.scaleY = scaleY;
		}

		_camPosX = BORDER;
		_camPosY = FlxG.stage.stageHeight - PREVIEW_H - BORDER;
		@:privateAccess
		{
			previewCam.flashSprite.x = _camPosX;
			previewCam.flashSprite.y = _camPosY;
		}

		FlxG.cameras.add(previewCam, false);

		// We alias camGame to previewCam so all stage/script cam refs work
		camGame  = previewCam;
		camHUD   = previewCam;
		camOther = previewCam;

		// --- Load song/stage data ---
		var song = states.PlayState.SONG;
		songName = Paths.formatToSongPath(song.song);

		Conductor.mapBPMChanges(song);
		Conductor.bpm = song.bpm;

		if (song.stage == null || song.stage.length < 1)
			song.stage = StageData.vanillaSongStage(songName);

		var stageName = song.stage;
		var stageData:StageFile = StageData.getStageFile(stageName);

		defaultCamZoom = stageData.defaultZoom;
		if (stageData.camera_speed != null)    cameraSpeed              = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend ?? [0.0, 0.0];
		opponentCameraOffset  = stageData.camera_opponent  ?? [0.0, 0.0];
		girlfriendCameraOffset = stageData.camera_girlfriend ?? [0.0, 0.0];

		BF_X  = stageData.boyfriend[0];
		BF_Y  = stageData.boyfriend[1];
		GF_X  = stageData.girlfriend[0];
		GF_Y  = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		// --- Character groups ---
		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup       = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup        = new FlxSpriteGroup(GF_X, GF_Y);

		// --- Compiled stage switch ---
		switch (stageName)
		{
			case 'stage':        new StageWeek1();
			case 'spooky':       new Spooky();
			case 'philly':       new Philly();
			case 'limo':         new Limo();
			case 'mall':         new Mall();
			case 'mallEvil':     new MallEvil();
			case 'school':       new School();
			case 'schoolEvil':   new SchoolEvil();
			case 'tank':         new Tank();
			case 'phillyStreets': new PhillyStreets();
			case 'phillyBlazin':  new PhillyBlazin();
		}

		// --- Lua/HScript debug group ---
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		luaDebugGroup = new FlxTypedGroup<psychlua.DebugLuaText>();
		luaDebugGroup.cameras = [previewCam];
		add(luaDebugGroup);
		#end

		// --- Characters ---
		if (!stageData.hide_girlfriend)
		{
			if (song.gfVersion == null || song.gfVersion.length < 1) song.gfVersion = 'gf';
			gf = new Character(0, 0, song.gfVersion);
			startCharacterPos(gf);
			gfGroup.add(gf);
		}

		if (song.player2 != null && song.player2.length > 0)
		{
			dad = new Character(0, 0, song.player2);
			startCharacterPos(dad, true);
			dadGroup.add(dad);
		}

		boyfriend = new Character(0, 0, song.player1, true);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);

		// Extra strumlines characters
		if (song.extraStrumlines != null)
		{
			for (strumData in song.extraStrumlines)
			{
				var isPlayer:Bool = (strumData.type == 'PLAYER');
				var extraChar:Character = new Character(0, 0, strumData.character, isPlayer);

				var baseX:Float = DAD_X;
				var baseY:Float = DAD_Y;
				switch (strumData.stagePosition)
				{
					case 'BF': baseX = BF_X; baseY = BF_Y;
					case 'GF': baseX = GF_X; baseY = GF_Y;
				}

				var extraGroup = new FlxSpriteGroup(baseX, baseY);
				extraGroup.add(extraChar);
				startCharacterPos(extraChar);
				extraCharacters.push(extraChar);
				extraCharacterGroups.push(extraGroup);
			}
		}

		// --- Stage JSON objects ---
		if (stageData.objects != null && stageData.objects.length > 0)
		{
			var list = StageData.addObjectsToState(stageData.objects,
				!stageData.hide_girlfriend ? gfGroup : null,
				dadGroup, boyfriendGroup, this);
			for (key => spr in list)
				if (!StageData.reservedNames.contains(key))
					variables.set(key, spr);
		}
		else
		{
			add(gfGroup);

			var dadExtras:Array<FlxSpriteGroup>  = [];
			var bfExtras:Array<FlxSpriteGroup>   = [];
			var gfExtras:Array<FlxSpriteGroup>   = [];

			if (song.extraStrumlines != null)
			{
				for (i in 0...extraCharacterGroups.length)
				{
					switch (song.extraStrumlines[i].stagePosition)
					{
						case 'BF': bfExtras.push(extraCharacterGroups[i]);
						case 'GF': gfExtras.push(extraCharacterGroups[i]);
						default:   dadExtras.push(extraCharacterGroups[i]);
					}
				}
			}

			for (g in gfExtras)  add(g);
			for (g in dadExtras) add(g);
			if (dad != null)     add(dadGroup);
			for (g in bfExtras)  add(g);
			add(boyfriendGroup);
		}

		// --- Lua/HScript stage + character scripts ---
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		#if LUA_ALLOWED     startLuasNamed('stages/' + stageName + '.lua');   #end
		#if HSCRIPT_ALLOWED startHScriptsNamed('stages/' + stageName + '.hx'); #end

		if (gf != null)       startCharacterScripts(gf.curCharacter);
		if (dad != null)      startCharacterScripts(dad.curCharacter);
		startCharacterScripts(boyfriend.curCharacter);
		#end

		// --- camFollow ---
		var camPos = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if (gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}
		if (dad != null && dad.curCharacter.startsWith('gf'))
		{
			dad.setPosition(GF_X, GF_Y);
			if (gf != null) gf.visible = false;
		}

		camFollow = new FlxObject();
		camFollow.setPosition(camPos.x, camPos.y);
		camPos.put();
		add(camFollow);

		previewCam.follow(camFollow, LOCKON, 0);
		previewCam.zoom = defaultCamZoom;
		previewCam.snapToTarget();
		moveCameraSection();

		// --- Collect events from chart ---
		_collectEvents();

		// --- eventPushed for compiled stages ---
		stagesFunc(function(stage:BaseStage) {
			for (ev in previewEventNotes)
				stage.eventPushed(ev);
		});
		// unique events
		var pushedEvents:Array<String> = [];
		for (ev in previewEventNotes)
		{
			if (!pushedEvents.contains(ev.event))
			{
				pushedEvents.push(ev.event);
				stagesFunc(function(stage:BaseStage) stage.eventPushedUnique(ev));
			}
		}

		// --- Custom event Lua/HScript scripts ---
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		for (ev in pushedEvents)
		{
			#if LUA_ALLOWED     startLuasNamed('custom_events/' + ev + '.lua');   #end
			#if HSCRIPT_ALLOWED startHScriptsNamed('custom_events/' + ev + '.hx'); #end
		}
		#end

		// Sort events by time
		previewEventNotes.sort(function(a, b) return Std.int(a.strumTime - b.strumTime));

		// createPost for stages
		stagesFunc(function(stage:BaseStage) stage.createPost());
		callOnScripts('onCreatePost');

		borderSprite = new openfl.display.Sprite();
		borderSprite.graphics.beginFill(0x000000, 0.01);
		borderSprite.graphics.drawRect(0, 0, PREVIEW_W, PREVIEW_H);
		borderSprite.graphics.endFill();
		borderSprite.x            = _camPosX;
		borderSprite.y            = _camPosY;
		borderSprite.mouseEnabled  = true;
		borderSprite.buttonMode    = true;
		borderSprite.mouseChildren = false;

		var _dragging:Bool = false;
		var _offX:Float    = 0;
		var _offY:Float    = 0;

		borderSprite.addEventListener(openfl.events.MouseEvent.MOUSE_DOWN, function(e:openfl.events.MouseEvent)
		{
			_dragging = true;
			_offX     = e.stageX - _camPosX;
			_offY     = e.stageY - _camPosY;
			e.stopPropagation();
		});

		FlxG.stage.addEventListener(openfl.events.MouseEvent.MOUSE_MOVE, function(e:openfl.events.MouseEvent)
		{
			if (!_dragging) return;
			_camPosX = e.stageX - _offX;
			_camPosY = e.stageY - _offY;
			borderSprite.x = _camPosX;
			borderSprite.y = _camPosY;
		});

		FlxG.stage.addEventListener(openfl.events.MouseEvent.MOUSE_UP, function(e:openfl.events.MouseEvent)
		{
			_dragging = false;
		});

		@:privateAccess
		{
			var camIdx = FlxG.stage.getChildIndex(previewCam.flashSprite);
			if (camIdx >= 0)
				FlxG.stage.addChildAt(borderSprite, camIdx + 1);
			else
				FlxG.stage.addChild(borderSprite);
		}

		// All sprites go to previewCam
		forEach(function(obj:flixel.FlxBasic) {
			if (obj != null && Std.isOfType(obj, flixel.FlxObject))
				cast(obj, flixel.FlxObject).cameras = [previewCam];
		});

		super.create();
	}

	override function update(elapsed:Float)
	{
		@:privateAccess
		{
			previewCam.flashSprite.x = _camPosX;
			previewCam.flashSprite.y = _camPosY;
		}

		if (!paused)
		{
			previewCam.followLerp = 0.04 * cameraSpeed;

			// Camera zoom lerp back
			if (camZooming)
			{
				previewCam.zoom = FlxMath.lerp(defaultCamZoom, previewCam.zoom,
					Math.exp(-elapsed * 3.125 * camZoomingDecay));
			}

			// Process events up to current song position
			_checkEventNotes();
		}

		super.update(elapsed);
		callOnScripts('onUpdate', [elapsed]);
	}

	// Called by ChartingState when the song position jumps (scrubbing)
	public function onSongPositionChanged(newPos:Float)
	{
		// Re-collect and re-sort events from scratch, discard already-passed ones
		_collectEvents();
		previewEventNotes = previewEventNotes.filter(function(e) return e.strumTime > newPos);
		previewEventNotes.sort(function(a, b) return Std.int(a.strumTime - b.strumTime));

		// Snap camera to correct section
		moveCameraSection(Std.int(newPos / (Conductor.stepCrochet * 16)));
	}

	override function beatHit()
	{
		if (lastBeatHit >= curBeat) return;
		characterBopper(curBeat);
		stagesFunc(function(stage:BaseStage) {
			stage.curBeat    = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
		callOnScripts('onBeatHit');
		lastBeatHit = curBeat;
		super.beatHit();
	}

	override function stepHit()
	{
		stagesFunc(function(stage:BaseStage) {
			stage.curStep    = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});
		callOnScripts('onStepHit');
		super.stepHit();
	}

	override function sectionHit()
	{
		if (lastSectionHit >= curSection) return;
		lastSectionHit = curSection;

		var song = states.PlayState.SONG;
		if (song.notes[curSection] != null)
		{
			if (targetCameraEventInstant) targetCameraEventInstant = false;

			if (!endingSong && !isCameraOnForcedPos)
				moveCameraSection();

			if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.data.camZooms)
			{
				previewCam.zoom += 0.015 * camZoomingMult;
			}

			if (song.notes[curSection].changeBPM)
				Conductor.bpm = song.notes[curSection].bpm;
		}

		stagesFunc(function(stage:BaseStage) {
			stage.curSection = curSection;
			stage.sectionHit();
		});
		callOnScripts('onSectionHit');
		super.sectionHit();
	}

	override function destroy()
	{
		// Restore previous PlayState.instance
		states.PlayState.instance = _prevPlayStateInstance;

		// Clean up scripts
		#if LUA_ALLOWED
		for (lua in luaArray) { lua.call('onDestroy', []); lua.stop(); }
		luaArray = null;
		FunkinLua.customFunctions.clear();
		#end
		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
			if (script != null) { if (script.exists('onDestroy')) script.call('onDestroy'); script.destroy(); }
		hscriptArray = null;
		#end

		stagesFunc(function(stage:BaseStage) stage.destroy());

		// Remove border
		if (borderSprite != null && FlxG.stage.contains(borderSprite))
			FlxG.stage.removeChild(borderSprite);

		// Remove preview camera
		if (FlxG.cameras.list.contains(previewCam))
			FlxG.cameras.remove(previewCam, true);

		super.destroy();
	}

	// ─── Camera helpers (mirrors PlayState) ─────────────────────────────────

	public function moveCameraSection(?sec:Null<Int>)
	{
		if (isCameraOnForcedPos)    return;
		if (targetCameraEventTween != null) return;
		if (targetCameraEventInstant)       return;

		var song = states.PlayState.SONG;
		if (sec == null) sec = curSection;
		if (sec < 0)     sec = 0;
		if (song.notes[sec] == null) return;

		var secData = song.notes[sec];
		var target:String = secData.mustHitTarget != null
			? secData.mustHitTarget
			: (secData.gfSection ? 'GF' : (secData.mustHitSection ? 'BF' : 'Dad'));

		if ((target == 'GF' || target == 'GF (Player)') && gf != null)
		{
			moveCameraToGirlfriend();
			return;
		}
		moveCamera(target != 'BF' && target != 'Boyfriend');
	}

	public function moveCameraToGirlfriend()
	{
		if (isCameraOnForcedPos || gf == null) return;
		camFollow.setPosition(gf.getMidpoint().x, gf.getMidpoint().y);
		camFollow.x += gf.cameraPosition[0]   + girlfriendCameraOffset[0];
		camFollow.y += gf.cameraPosition[1]   + girlfriendCameraOffset[1];
	}

	public function moveCamera(isDad:Bool)
	{
		if (isCameraOnForcedPos) return;
		if (isDad)
		{
			if (dad == null) return;
			camFollow.setPosition(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
			camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
		}
		else
		{
			if (boyfriend == null) return;
			camFollow.setPosition(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];
		}
	}

	// ─── Character helpers ───────────────────────────────────────────────────

	function startCharacterPos(char:Character, ?gfCheck:Bool = false)
	{
		if (gfCheck && char.curCharacter.startsWith('gf'))
		{
			char.setPosition(GF_X, GF_Y);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public function characterBopper(beat:Int)
	{
		if (gf != null && beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0
			&& !gf.getAnimationName().startsWith('sing') && !gf.stunned)
			gf.dance();
		if (boyfriend != null && beat % boyfriend.danceEveryNumBeats == 0
			&& !boyfriend.getAnimationName().startsWith('sing') && !boyfriend.stunned)
			boyfriend.dance();
		if (dad != null && beat % dad.danceEveryNumBeats == 0
			&& !dad.getAnimationName().startsWith('sing') && !dad.stunned)
			dad.dance();
		for (ec in extraCharacters)
			if (ec != null && beat % ec.danceEveryNumBeats == 0
				&& !ec.getAnimationName().startsWith('sing') && !ec.stunned)
				ec.dance();
	}

	// ─── Stage helpers ───────────────────────────────────────────────────────

	public function stagesFunc(func:BaseStage->Void)
	{
		for (stage in stages)
			if (stage != null && stage.exists && stage.active)
				func(stage);
	}

	// ─── Event processing ────────────────────────────────────────────────────

	function _collectEvents()
	{
		previewEventNotes = [];
		var song = states.PlayState.SONG;
		if (song == null || song.notes == null) return;

		for (section in song.notes)
		{
			if (section == null || section.sectionNotes == null) continue;
			for (note in section.sectionNotes)
			{
				if (note == null || note.length < 3) continue;
				if (Math.isNaN(note[0])) continue;
				var isEvent:Bool = (note[1] < 0);
				if (!isEvent) continue;

				var ev:EventNote = {
					strumTime: note[0] + Conductor.offset,
					event:     note[2],
					value1:    note.length > 3 ? note[3] : '',
					value2:    note.length > 4 ? note[4] : ''
				};
				previewEventNotes.push(ev);
			}
		}
	}

	function _checkEventNotes()
	{
		while (previewEventNotes.length > 0)
		{
			if (Conductor.songPosition < previewEventNotes[0].strumTime) break;
			var ev = previewEventNotes.shift();
			var v1 = ev.value1 ?? '';
			var v2 = ev.value2 ?? '';
			// Fire on compiled stages
			var fl1:Null<Float> = Std.parseFloat(v1); if (Math.isNaN(fl1)) fl1 = null;
			var fl2:Null<Float> = Std.parseFloat(v2); if (Math.isNaN(fl2)) fl2 = null;
			stagesFunc(function(stage:BaseStage)
				stage.eventCalled(ev.event, v1, v2, fl1, fl2, ev.strumTime));
			// Fire on Lua/HScript
			callOnScripts('onEvent', [ev.event, v1, v2, ev.strumTime]);
		}
	}

	// ─── Script helpers (mirrors PlayState public API) ────────────────────────

	#if LUA_ALLOWED
	public function startLuasNamed(luaFile:String)
	{
		#if MODS_ALLOWED
		var path = Paths.modFolders(luaFile);
		if (!FileSystem.exists(path)) path = Paths.getSharedPath(luaFile);
		if (FileSystem.exists(path))
		{
			for (s in luaArray) if (s.scriptName == path) return;
			new FunkinLua(path);
		}
		#elseif sys
		var path = Paths.getSharedPath(luaFile);
		if (FileSystem.exists(path))
		{
			for (s in luaArray) if (s.scriptName == path) return;
			new FunkinLua(path);
		}
		#end
	}
	#end

	#if HSCRIPT_ALLOWED
	public function startHScriptsNamed(scriptFile:String)
	{
		#if MODS_ALLOWED
		var path = Paths.modFolders(scriptFile);
		if (!FileSystem.exists(path)) path = Paths.getSharedPath(scriptFile);
		#else
		var path = Paths.getSharedPath(scriptFile);
		#end
		if (!FileSystem.exists(path)) return;
		if (Iris.instances.exists(path))  return;
		initHScript(path);
	}

	public function initHScript(file:String)
	{
		try
		{
			var script = new HScript(null, file);
			hscriptArray.push(script);
			if (script.exists('onCreate')) script.call('onCreate');
		}
		catch (e:Dynamic) { trace('HScript error ($file): $e'); }
	}
	#end

	function startCharacterScripts(name:String)
	{
		#if LUA_ALLOWED
		startLuasNamed('characters/$name.lua');
		#end
		#if HSCRIPT_ALLOWED
		startHScriptsNamed('characters/$name.hx');
		#end
	}

	public function callOnScripts(func:String, args:Array<Dynamic> = null,
		ignoreStops:Bool = false, exclusions:Array<String> = null,
		excludeValues:Array<Dynamic> = null):Dynamic
	{
		var ret:Dynamic = LuaUtils.Function_Continue;
		#if LUA_ALLOWED
		ret = callOnLuas(func, args, ignoreStops, exclusions, excludeValues);
		#end
		#if HSCRIPT_ALLOWED
		var hret = callOnHScript(func, args, ignoreStops, exclusions, excludeValues);
		if (hret != null && hret != LuaUtils.Function_Continue) ret = hret;
		#end
		return ret;
	}

	#if LUA_ALLOWED
	public function callOnLuas(func:String, args:Array<Dynamic> = null,
		ignoreStops:Bool = false, exclusions:Array<String> = null,
		excludeValues:Array<Dynamic> = null):Dynamic
	{
		if (args == null)          args = [];
		if (exclusions == null)    exclusions = [];
		if (excludeValues == null) excludeValues = [LuaUtils.Function_Continue];
		var ret:Dynamic = LuaUtils.Function_Continue;
		var i:Int = 0;
		while (i < luaArray.length)
		{
			var script = luaArray[i];
			if (exclusions.contains(script.scriptName)) { i++; continue; }
			var val = script.call(func, args);
			if (val != null && !excludeValues.contains(val)) ret = val;
			if (!ignoreStops && ret == LuaUtils.Function_Stop) break;
			if (luaArray[i] == script) i++;
		}
		return ret;
	}
	#end

	#if HSCRIPT_ALLOWED
	public function callOnHScript(func:String, args:Array<Dynamic> = null,
		ignoreStops:Bool = false, exclusions:Array<String> = null,
		excludeValues:Array<Dynamic> = null):Dynamic
	{
		if (args == null)          args = [];
		if (exclusions == null)    exclusions = [];
		if (excludeValues == null) excludeValues = [LuaUtils.Function_Continue];
		var ret:Dynamic = LuaUtils.Function_Continue;
		for (script in hscriptArray)
		{
			if (script == null || exclusions.contains(script.origin)) continue;
			if (!script.exists(func)) continue;
			try
			{
				var val = script.call(func, args);
				if (val != null && !excludeValues.contains(val)) ret = val;
				if (!ignoreStops && ret == LuaUtils.Function_Stop) break;
			}
			catch (e:Dynamic) {}
		}
		return ret;
	}
	#end

	public function setOnScripts(variable:String, arg:Dynamic,
		exclusions:Array<String> = null)
	{
		if (exclusions == null) exclusions = [];
		#if LUA_ALLOWED
		for (script in luaArray)
			if (!exclusions.contains(script.scriptName))
				script.set(variable, arg);
		#end
		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
			if (script != null && !exclusions.contains(script.origin))
				script.set(variable, arg);
		#end
	}

	public function getLuaObject(tag:String):Dynamic
		return variables.get(tag);

	public function addTextToDebug(text:String, color:FlxColor)
	{
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		if (luaDebugGroup == null) return;
		var item = luaDebugGroup.recycle(psychlua.DebugLuaText);
		item.text = text;
		item.color = color;
		luaDebugGroup.remove(item, true);
		luaDebugGroup.insert(0, item);
		#end
	}
}
