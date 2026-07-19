package backend;

import flixel.FlxState;
import psychlua.HScript;

class HScriptState extends MusicBeatState
{
	public var hscript:HScript;
	public var stateName:String;
	public var modDirectory:String;
	public var oldStickers:Array<substates.StickerSubState.StickerSprite>;
	public var isInitialState:Bool = false;
	
	public function new(script:HScript, name:String, ?modDir:String, ?stickers:Array<substates.StickerSubState.StickerSprite>)
	{
		super();
		this.hscript = script;
		this.stateName = name;
		this.modDirectory = modDir;
		this.oldStickers = stickers;
		
		if(modDirectory != null && modDirectory != '')
		{
			Mods.currentModDirectory = modDirectory;
		}
	}
	
	override function create()
	{
		if(modDirectory != null && modDirectory != '')
		{
			Mods.currentModDirectory = modDirectory;
		}
		
		persistentUpdate = true;
		super.create();
		
		if(hscript != null && hscript.exists('create'))
		{
			hscript.call('create', [this]);
		}

		if(hscript != null && hscript.exists('isInitialState'))
		{
			var result = hscript.call('isInitialState', []);
			if(result != null && result.returnValue == true)
			{
				isInitialState = true;
			}
		}

		#if CHECK_FOR_UPDATES
		if(stateName == 'MainMenuState' && substates.OutdatedSubState.updateVersion != null
			&& ClientPrefs.data.checkForUpdates
			&& Std.parseFloat(substates.OutdatedSubState.updateVersion) > Std.parseFloat(states.MainMenuState.cheeseEngineVersion))
		{
			persistentUpdate = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		#if CHECK_FOR_UPDATES
		if(stateName == 'MainMenuState' && ClientPrefs.data.checkForUpdates
			&& substates.OutdatedSubState.updateVersion != null
			&& Std.parseFloat(substates.OutdatedSubState.updateVersion) > Std.parseFloat(states.MainMenuState.cheeseEngineVersion))
		{
			persistentUpdate = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		var pending = substates.StickerSubState.pendingStickers;
		if(pending != null && pending.length > 0)
		{
			this.persistentUpdate = false;
			this.persistentDraw = true;
		}
	}
	
	override function closeSubState()
	{
		persistentUpdate = true;
		super.closeSubState();
		
		if(hscript != null && hscript.exists('create'))
		{
			if(hscript.exists('onCloseSubState'))
				hscript.call('onCloseSubState', []);
			else
				FlxG.mouse.visible = true;
		}
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		var _hasBlockingSubState:Bool = subState != null
			&& !Std.isOfType(subState, CustomFadeTransition)
			&& !Std.isOfType(subState, substates.StickerSubState);

		if(!_hasBlockingSubState)
		{
			if(stateName == 'MainMenuState' && FlxG.keys.justPressed.TAB)
			{
				var sub = new backend.ModSelectorSubstate();
				sub._mouseWasVisible = FlxG.mouse.visible;
				FlxG.mouse.visible = false;
				openSubState(sub);
			}

			if(hscript != null && hscript.exists('update'))
			hscript.call('update', [elapsed]);
		}
	}	
	
	var lastStepHit:Int = -1;
	override function stepHit()
	{
		super.stepHit();
		
		if(curStep == lastStepHit)
			return;
		
		lastStepHit = curStep;
		if(hscript != null && hscript.exists('onStepHit'))
		{
			hscript.set('curStep', curStep);
			hscript.call('onStepHit', []);
		}
	}
	
	var lastBeatHit:Int = -1;
	override function beatHit()
	{
		super.beatHit();
		
		if(curBeat == lastBeatHit)
			return;
		
		lastBeatHit = curBeat;
		if(hscript != null && hscript.exists('onBeatHit'))
		{
			hscript.set('curBeat', curBeat);
			hscript.call('onBeatHit', []);
		}
	}
	
	override function destroy()
	{
		if(hscript != null)
			hscript.destroy();
		super.destroy();
	}
}

class HScriptStateLoader
{
	public static function loadStateScript(stateName:String):FlxState
	{
		#if HSCRIPT_ALLOWED
		#if MODS_ALLOWED
		
		var save = FlxG.save;
		var modMode:String = null;
		if(save != null && save.data != null && save.data.modMode != null)
		{
			modMode = save.data.modMode;
		}
		
		if(modMode == 'DISABLE MODS' || modMode == 'MODS + FNF SONGS' || modMode == 'ALL MODS')
		{
			return null;
		}
		
		var savedModDirectory = Mods.currentModDirectory;
		
		if(savedModDirectory == null || savedModDirectory == '')
		{
			if(save != null && save.data != null && save.data.currentMod != null && save.data.currentMod != '')
			{
				savedModDirectory = save.data.currentMod;
			}
		}
		
		if(savedModDirectory != null && savedModDirectory != '')
		{
			var statesDir = Paths.modFolders('$savedModDirectory/states/');
			var scriptPath = findScriptInDir(statesDir, '$stateName.hx');
			var exists = scriptPath != null;

			if(exists && stateName != 'LoadingState' && stateName != 'LoadingScreen')
			{
				Mods.currentModDirectory = savedModDirectory;
				Mods.loadTopMod();
				
				try
				{
					var hscript = new HScript(null, scriptPath, null, false);
					hscript.set('state', null);
					
					var stateInstance = new HScriptState(hscript, stateName, savedModDirectory, null);
					hscript.set('state', stateInstance);
					hscript.set('add', function(obj:Dynamic) { return stateInstance.add(obj); });
					hscript.set('remove', function(obj:Dynamic, splice:Bool = false) { return stateInstance.remove(obj, splice); });
					hscript.set('insert', function(position:Int, obj:Dynamic) { return stateInstance.insert(position, obj); });
					hscript.set('members', stateInstance.members);
					hscript.set('camera', FlxG.camera);
					hscript.set('cameras', FlxG.cameras);
					hscript.set('save', FlxG.save);
					hscript.set('sound', FlxG.sound);
					hscript.set('openSubState', function(substate:Dynamic) { stateInstance.openSubState(substate); });
					hscript.set('closeSubState', function() { stateInstance.closeSubState(); });
					hscript.set('switchState', function(nextState:Dynamic) { backend.MusicBeatState.switchState(nextState); });
					hscript.set('switchStateDirect', function(nextState:Dynamic) { backend.MusicBeatState.switchStateDirect(nextState); });
					hscript.set('switchStateByName', function(name:String) { backend.MusicBeatState.switchStateByName(name); });
					hscript.set('switchStateDirectByName', function(name:String) { backend.MusicBeatState.switchStateDirectByName(name); });
					hscript.set('resetState', function() { FlxG.resetState(); });
					hscript.set('persistentUpdate', stateInstance.persistentUpdate);
					hscript.set('persistentDraw', stateInstance.persistentDraw);
					
					return stateInstance;
				}
				catch(e:Dynamic)
				{
				}
			}
		}
		#end
		#end
		
		return null;
	}
	public static function findScriptInDir(dir:String, fileName:String):String
	{
		if(!sys.FileSystem.exists(dir) || !sys.FileSystem.isDirectory(dir))
			return null;

		var direct = dir + fileName;
		if(sys.FileSystem.exists(direct))
			return direct;

		for(entry in sys.FileSystem.readDirectory(dir))
		{
			var full = dir + entry;
			if(sys.FileSystem.isDirectory(full))
			{
				var found = findScriptInDir(full + '/', fileName);
				if(found != null) return found;
			}
		}
		return null;
	}
}