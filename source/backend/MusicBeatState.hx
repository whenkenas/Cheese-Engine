package backend;

import openfl.display.BitmapData;
import flixel.FlxState;
import flixel.util.FlxSave;
import backend.PsychCamera;
import debug.CMD;

class MusicBeatState extends FlxState
{
	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	public var controls(get, never):Controls;
	private function get_controls()
	{
		return Controls.instance;
	}

	var _psychCameraInitialized:Bool = false;

	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	public static function getVariables()
		return getState().variables;

	override function create() {
		var skip:Bool = FlxTransitionableState.skipNextTransOut;
		backend.CursorLoader.load();
		#if MODS_ALLOWED Mods.updatedOnState = false; #end

		try {
			Reflect.setProperty(Type.resolveClass('states.PlayState'), 'introSoundsSuffix', '');
		} catch(e:Dynamic) {}

		if(!_psychCameraInitialized) initPsychCamera();

		super.create();

		var pending = substates.StickerSubState.pendingStickers;

		if(!skip && pending == null) {
			openSubState(new CustomFadeTransition(0.5, true));
		}
		FlxTransitionableState.skipNextTransOut = false;
		FlxTransitionableState.skipNextTransIn = false;
		timePassedOnState = 0;

		if(pending != null)
		{
			substates.StickerSubState.pendingStickers = null;
			openSubState(new substates.StickerSubState(pending));
		}
	}

	public function initPsychCamera():PsychCamera
	{
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_psychCameraInitialized = true;
		//trace('initialized psych camera ' + Sys.cpuTime());
		return camera;
	}

	public static var timePassedOnState:Float = 0;
	public static var _cachedConsoleKeys:Array<flixel.input.keyboard.FlxKey> = null;

	override function update(elapsed:Float)
	{
		//everyStep();
		var oldStep:Int = curStep;
		timePassedOnState += elapsed;

		updateCurStep();
		updateBeat();

		if(_cachedConsoleKeys == null)
			_cachedConsoleKeys = ClientPrefs.keyBinds.get('debug_console');

		if(_cachedConsoleKeys != null && ClientPrefs.data.developerMode) {
			for (key in _cachedConsoleKeys) {
				if (FlxG.keys.checkStatus(key, JUST_PRESSED)) {
					CMD.openCMD();
					break;
				}
			}
		}

		if(ClientPrefs.data.developerMode && FlxG.keys.justPressed.SEVEN && FlxG.state.subState == null)
		{
			var parts = Type.getClassName(Type.getClass(FlxG.state)).split('.');
			var stateName = parts[parts.length - 1];
			if(stateName == 'HScriptState' && Std.isOfType(FlxG.state, HScriptStateLoader.HScriptState))
			{
				var hscriptState:HScriptStateLoader.HScriptState = cast FlxG.state;
				stateName = hscriptState.stateName;
			}
			else if(stateName == 'LuaState' && Std.isOfType(FlxG.state, psychlua.LuaStateLoader.LuaState))
			{
				var luaState:psychlua.LuaStateLoader.LuaState = cast FlxG.state;
				stateName = luaState.stateName;
			}
			if(stateName.toLowerCase() == 'mainmenustate')
			{
				backend.EditorHelper.saveCurrentState();
				FlxG.state.openSubState(new states.editors.EditorPickerSubstate());
			}
		}

		if (oldStep != curStep)
		{
			if(curStep > 0)
				stepHit();

			if(PlayState.SONG != null)
			{
				if (oldStep < curStep)
					updateSection();
				else
					rollbackSection();
			}
		}

		if(FlxG.save.data != null && FlxG.save.data.fullscreen != FlxG.fullscreen)
			FlxG.save.data.fullscreen = FlxG.fullscreen;

		#if DISCORD_ALLOWED
		if(backend.DiscordClient._pendingPresenceUpdate)
		{
			backend.DiscordClient._pendingPresenceUpdate = false;
			backend.DiscordClient.changePresence();
		}
		#end
		
		stagesFunc(function(stage:BaseStage) {
			stage.update(elapsed);
		});

		super.update(elapsed);
	}

	private function updateSection():Void
	{
		if(stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while(curStep >= stepsToDo)
		{
			curSection++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}

	private function rollbackSection():Void
	{
		if(curStep < 0) return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if(stepsToDo > curStep) break;
				
				curSection++;
			}
		}

		if(curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public static function switchStateWithStickers(nextState:FlxState, ?mode:String) {
		if (nextState == null) return;
		if (mode != null) substates.StickerSubState.stickerMode = mode;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		FlxG.state.openSubState(new substates.StickerSubState(null, function(_) return nextState));
	}

	public static function switchStateWithStickersByName(stateName:String, ?mode:String) {
		if (mode != null) substates.StickerSubState.stickerMode = mode;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		FlxG.state.openSubState(new substates.StickerSubState(null, function(_) {
			#if HSCRIPT_ALLOWED
			var hscriptState = HScriptStateLoader.loadStateScript(stateName);
			if (hscriptState != null) return hscriptState;
			#end
			#if LUA_ALLOWED
			var luaState = psychlua.LuaStateLoader.loadStateScript(stateName);
			if (luaState != null) return luaState;
			#end
			var stateClass = backend.StateManager.getStateClass(stateName);
			if (stateClass != null) return Type.createInstance(stateClass, []);
			return new states.MainMenuState();
		}));
	}

	public static function switchStateDirect(nextState:FlxState = null) {
		FlxTransitionableState.skipNextTransIn = true;
		switchState(nextState);
	}

	public static function switchStateDirectByName(stateName:String) {
		FlxTransitionableState.skipNextTransIn = true;
		switchStateByName(stateName);
	}

	public static function switchStateByName(stateName:String) {
		#if HSCRIPT_ALLOWED
		var hscriptState = HScriptStateLoader.loadStateScript(stateName);
		if (hscriptState != null) { switchState(hscriptState); return; }
		#end
		#if LUA_ALLOWED
		var luaState = psychlua.LuaStateLoader.loadStateScript(stateName);
		if (luaState != null) { switchState(luaState); return; }
		#end
		var stateClass = backend.StateManager.getStateClass(stateName);
		if (stateClass != null) switchState(Type.createInstance(stateClass, []));
		else switchState(new states.MainMenuState());
	}

	public static function switchState(nextState:FlxState = null) {
		if(nextState == null) nextState = FlxG.state;
		if(nextState == FlxG.state)
		{
			resetState();
			return;
		}

		_cachedModMode = null;

		#if MODS_ALLOWED
		var currentMode = getCurrentModMode();
		if(currentMode != 'DISABLE MODS' && Mods.currentModDirectory != null && Mods.currentModDirectory != '')
		{
			var stateClassName = Type.getClassName(Type.getClass(nextState));
			if(stateClassName != null)
			{
				var parts = stateClassName.split('.');
				var stateName = parts[parts.length - 1];

				#if HSCRIPT_ALLOWED
				var hscriptState = HScriptStateLoader.loadStateScript(stateName);
				if(hscriptState != null)
					nextState = hscriptState;
				#end
				#if LUA_ALLOWED
				var luaState = psychlua.LuaStateLoader.loadStateScript(stateName);
				if(luaState != null)
					nextState = luaState;
				#end
			}
		}
		#end

		if(FlxTransitionableState.skipNextTransIn) FlxG.switchState(nextState);
		else startTransition(nextState);
		FlxTransitionableState.skipNextTransIn = false;
	}

	static var _cachedModMode:String = null;

	static function getCurrentModMode():String
	{
		if(_cachedModMode != null)
			return _cachedModMode;

		if(FlxG.save.data != null && FlxG.save.data.modMode != null)
		{
			var mode:String = FlxG.save.data.modMode;
			if(mode == 'MODS + FNF SONGS' || mode == 'ALL MODS' || mode == 'DISABLE MODS')
			{
				_cachedModMode = mode;
				return _cachedModMode;
			}
		}

		if(Mods.currentModDirectory != null && Mods.currentModDirectory != '')
			_cachedModMode = 'SINGLE MOD';
		else
			_cachedModMode = 'DISABLE MODS';

		return _cachedModMode;
	}

	public static function hardResetToState(nextState:FlxState) {
		if(FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			FlxG.sound.music = null;
		}
		
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		
		#if MODS_ALLOWED
		Mods.loadTopMod();
		#end
		
		FlxTransitionableState.skipNextTransIn = false;
		startTransition(nextState);
	}

	public static function resetState() {
		#if MODS_ALLOWED
		var currentMode = getCurrentModMode();
		if(currentMode == 'SINGLE MOD' && Mods.currentModDirectory != null && Mods.currentModDirectory != '')
		{
			var currentStateClassName = Type.getClassName(Type.getClass(FlxG.state));
			if(currentStateClassName != null)
			{
				var parts = currentStateClassName.split('.');
				var stateName = parts[parts.length - 1];

				#if HSCRIPT_ALLOWED
				var hscriptState = HScriptStateLoader.loadStateScript(stateName);
				if(hscriptState != null)
				{
					switchState(hscriptState);
					return;
				}
				#end
				#if LUA_ALLOWED
				var luaState = psychlua.LuaStateLoader.loadStateScript(stateName);
				if(luaState != null)
				{
					switchState(luaState);
					return;
				}
				#end
			}
		}
		#end

		if(FlxTransitionableState.skipNextTransIn) FlxG.resetState();
		else startTransition();
		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	public static function startTransition(nextState:FlxState = null)
	{
		if(nextState == null)
			nextState = FlxG.state;

		FlxG.state.openSubState(new CustomFadeTransition(0.5, false));
		if(nextState == FlxG.state)
			CustomFadeTransition.finishCallback = function() FlxG.resetState();
		else
			CustomFadeTransition.finishCallback = function() FlxG.switchState(nextState);
	}

	public static function getState():MusicBeatState {
		return cast (FlxG.state, MusicBeatState);
	}

	public function stepHit():Void
	{
		stagesFunc(function(stage:BaseStage) {
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0)
			beatHit();
	}

	public var stages:Array<BaseStage> = [];
	public function beatHit():Void
	{
		//trace('Beat: ' + curBeat);
		stagesFunc(function(stage:BaseStage) {
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
	}

	public function sectionHit():Void
	{
		//trace('Section: ' + curSection + ', Beat: ' + curBeat + ', Step: ' + curStep);
		stagesFunc(function(stage:BaseStage) {
			stage.curSection = curSection;
			stage.sectionHit();
		});
	}

	function stagesFunc(func:BaseStage->Void)
	{
		for (stage in stages)
			if(stage != null && stage.exists && stage.active)
				func(stage);
	}

	function getBeatsOnSection()
	{
		var val:Null<Float> = 4;
		if(PlayState.SONG != null && PlayState.SONG.notes[curSection] != null) val = PlayState.SONG.notes[curSection].sectionBeats;
		return val == null ? 4 : val;
	}

	override function destroy()
	{
		if (FlxG.camera != null)
			FlxG.camera.bgColor = FlxColor.BLACK;
		super.destroy();
	}
}