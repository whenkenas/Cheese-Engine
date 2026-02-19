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
		
		if(oldStickers != null && oldStickers.length > 0)
		{
			this.persistentUpdate = false;
			this.persistentDraw = true;
			var stickerSubState = new substates.StickerSubState(oldStickers, null);
			openSubState(stickerSubState);
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
		
		if(stateName == 'MainMenuState' && FlxG.keys.justPressed.TAB)
		{
			FlxG.mouse.visible = false;
			persistentUpdate = false;
			openSubState(new backend.ModSelectorSubstate());
		}
		
		if(hscript != null && hscript.exists('update'))
			hscript.call('update', [elapsed]);
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
		
		if(modMode == 'DISABLE MODS')
		{
			return null;
		}
		
		var savedModDirectory = Mods.currentModDirectory;
		
		if(savedModDirectory == null || savedModDirectory == '')
		{
			if(save != null && save.data != null && save.data.currentMod != null && save.data.currentMod != '')
			{
				savedModDirectory = save.data.currentMod;
				Mods.currentModDirectory = savedModDirectory;
			}
		}
		
		if(savedModDirectory != null && savedModDirectory != '')
		{
			var scriptPath = Paths.modFolders('$savedModDirectory/states/$stateName.hx');
			var exists = sys.FileSystem.exists(scriptPath);
			
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
					hscript.set('switchState', function(nextState:Dynamic) { FlxG.switchState(nextState); });
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
}