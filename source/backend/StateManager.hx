package backend;

import flixel.FlxState;

class StateManager
{
	public static function getStateClass(stateName:String):Class<FlxState>
	{
		var stateClass:Class<FlxState> = null;
		
		#if MODS_ALLOWED
		if(Mods.currentModDirectory != null && Mods.currentModDirectory != '')
		{
			var sanitizedModName = sanitizeModName(Mods.currentModDirectory);
			var modStatePath = 'states.mods.$sanitizedModName.$stateName';
			var resolvedClass = Type.resolveClass(modStatePath);
			
			if(resolvedClass != null)
			{
				stateClass = cast resolvedClass;
				trace('Loading custom compiled state from mod: $modStatePath');
				return stateClass;
			}
		}
		#end
		
		var originalPath = 'states.$stateName';
		var resolvedClass = Type.resolveClass(originalPath);
		
		if(resolvedClass != null)
		{
			stateClass = cast resolvedClass;
			trace('Loading original state: $originalPath');
			return stateClass;
		}
		
		var optionsPath = 'options.$stateName';
		resolvedClass = Type.resolveClass(optionsPath);
		
		if(resolvedClass != null)
		{
			stateClass = cast resolvedClass;
			trace('Loading options state: $optionsPath');
			return stateClass;
		}
		
		trace('State not found: $stateName');
		return null;
	}
	
	public static function switchState(stateName:String):Void
	{
		trace('=== StateManager.switchState called with: $stateName ===');
		
		#if HSCRIPT_ALLOWED
		trace('Checking for HScript state...');
		var hscriptState = HScriptStateLoader.loadStateScript(stateName);
		if(hscriptState != null)
		{
			trace('HScript state found! Loading: $stateName');
			MusicBeatState.switchState(hscriptState);
			return;
		}
		else
		{
			trace('No HScript state found for: $stateName');
		}
		#end
		#if LUA_ALLOWED
		trace('Checking for Lua state...');
		var luaState = psychlua.LuaStateLoader.loadStateScript(stateName);
		if(luaState != null)
		{
			trace('Lua state found! Loading: $stateName');
			MusicBeatState.switchState(luaState);
			return;
		}
		else
		{
			trace('No Lua state found for: $stateName');
		}
		#end
		
		trace('Looking for compiled state class...');
		var stateClass = getStateClass(stateName);
		
		if(stateClass != null)
		{
			trace('Compiled state found! Creating instance: $stateName');
			var stateInstance:FlxState = Type.createInstance(stateClass, []);
			MusicBeatState.switchState(stateInstance);
		}
		else
		{
			trace('ERROR: Could not find state: $stateName (not HScript, not compiled)');
			trace('Falling back to TitleState');
			var fallbackClass = getStateClass('TitleState');
			if(fallbackClass != null)
			{
				var fallbackInstance:FlxState = Type.createInstance(fallbackClass, []);
				MusicBeatState.switchState(fallbackInstance);
			}
		}
	}

	public static function loadLuaState(stateName:String, ?stickers:Array<substates.StickerSubState.StickerSprite>):FlxState
	{
		#if LUA_ALLOWED
		var luaState = psychlua.LuaStateLoader.loadStateScript(stateName, stickers);
		if(luaState != null) return luaState;
		#end
		return null;
	}
	
	static function sanitizeModName(modName:String):String
	{
		var sanitized = modName;
		sanitized = StringTools.replace(sanitized, " ", "_");
		sanitized = StringTools.replace(sanitized, ".", "_");
		sanitized = StringTools.replace(sanitized, "!", "_");
		sanitized = StringTools.replace(sanitized, "-", "_");
		sanitized = StringTools.replace(sanitized, "'", "_");
		sanitized = StringTools.replace(sanitized, "&", "_");
		return sanitized;
	}
}