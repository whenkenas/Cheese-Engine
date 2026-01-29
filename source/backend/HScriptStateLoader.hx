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
			trace('DEBUG HScriptState constructor: Set Mods.currentModDirectory to $modDirectory');
		}
	}
	
	override function create()
	{
		if(modDirectory != null && modDirectory != '')
		{
			Mods.currentModDirectory = modDirectory;
			trace('DEBUG HScriptState.create: BEFORE super.create(), Mods.currentModDirectory = ${Mods.currentModDirectory}');
		}
		
		persistentUpdate = true;
		super.create();
		
		trace('DEBUG HScriptState.create: AFTER super.create(), Mods.currentModDirectory = ${Mods.currentModDirectory}');
		
		if(hscript != null && hscript.exists('create'))
		{
			trace('DEBUG HScriptState.create: BEFORE calling hscript create, Mods.currentModDirectory = ${Mods.currentModDirectory}');
			hscript.call('create', [this]);
		}

		if(hscript != null && hscript.exists('isInitialState'))
		{
			var result = hscript.call('isInitialState', []);
			if(result != null && result.returnValue == true)
			{
				isInitialState = true;
				trace('DEBUG HScriptState: This state is marked as initial state');
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
		trace('>>> HScriptStateLoader.loadStateScript called for: $stateName');
		
		#if HSCRIPT_ALLOWED
		trace('HSCRIPT_ALLOWED is enabled');
		#if MODS_ALLOWED
		trace('MODS_ALLOWED is enabled');
		
		var save = FlxG.save;
		var modMode:String = null;
		if(save != null && save.data != null && save.data.modMode != null)
		{
			modMode = save.data.modMode;
			trace('DEBUG: modMode from save = $modMode');
		}
		
		if(modMode == 'DISABLE MODS')
		{
			trace('DEBUG: DISABLE MODS mode active, skipping HScript loading');
			trace('>>> Returning null from HScriptStateLoader');
			return null;
		}
		
		trace('Current mod directory: ${Mods.currentModDirectory}');
		
		var savedModDirectory = Mods.currentModDirectory;
		trace('DEBUG: Saved mod directory: $savedModDirectory');
		
		if(savedModDirectory == null || savedModDirectory == '')
		{
			trace('DEBUG: No saved mod, trying to load from save data');
			if(save != null && save.data != null && save.data.currentMod != null && save.data.currentMod != '')
			{
				savedModDirectory = save.data.currentMod;
				Mods.currentModDirectory = savedModDirectory;
				trace('DEBUG: Restored mod from save: $savedModDirectory');
			}
		}
		
		trace('DEBUG: About to check currentModDirectory');
		trace('DEBUG: currentModDirectory value = "$savedModDirectory"');
		trace('DEBUG: Is null? ${savedModDirectory == null}');
		trace('DEBUG: Is empty? ${savedModDirectory == ""}');
		
		if(savedModDirectory != null && savedModDirectory != '')
		{
			trace('DEBUG: Inside if block, currentModDirectory is valid');
			var scriptPath = Paths.modFolders('$savedModDirectory/states/$stateName.hx');
			trace('DEBUG: Full scriptPath = $scriptPath');
			trace('DEBUG: Checking if file exists...');
			var exists = sys.FileSystem.exists(scriptPath);
			trace('DEBUG: File exists? $exists');
			
			if(exists)
			{
				trace('âœ“ Script file found! Loading HScript state from: $scriptPath');
				trace('DEBUG: About to create HScript instance');
				
				Mods.currentModDirectory = savedModDirectory;
				trace('DEBUG: Restored Mods.currentModDirectory to: $savedModDirectory');
				
				Mods.loadTopMod();
				trace('DEBUG: Called Mods.loadTopMod()');
				
				try
				{
					var hscript = new HScript(null, scriptPath, null, false);
					trace('DEBUG: HScript instance created');
					hscript.set('state', null);
					trace('DEBUG: Set state to null');
					
					var stateInstance = new HScriptState(hscript, stateName, savedModDirectory, null);
					trace('DEBUG: HScriptState instance created');
					hscript.set('state', stateInstance);
					trace('DEBUG: Set state to instance');
					
					trace('✓ HScript state created successfully!');
					trace('DEBUG: Returning state instance');
					return stateInstance;
				}
				catch(e:Dynamic)
				{
					trace('âœ— ERROR loading HScript state: $e');
					trace('DEBUG: Exception details: $e');
				}
			}
			else
			{
				trace('âœ— Script file does NOT exist at path: $scriptPath');
			}
		}
		else
		{
			trace('No mod directory active (currentModDirectory is null or empty)');
			trace('DEBUG: Skipped checking for HScript because no mod is active');
		}
		#else
		trace('MODS_ALLOWED is NOT enabled');
		#end
		#else
		trace('HSCRIPT_ALLOWED is NOT enabled');
		#end
		
		trace('>>> Returning null from HScriptStateLoader');
		return null;
	}
}