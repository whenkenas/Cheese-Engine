package states;

import backend.StateManager;

class InitialState extends MusicBeatState
{
	var loadedState:Bool = false;
	
	override public function create():Void
	{
		super.create();
		
		FlxG.mouse.visible = false;
		
		#if MODS_ALLOWED
		var _save = FlxG.save;
		var _modMode:String = (_save != null && _save.data != null) ? _save.data.modMode : null;
		var _isSingleMod:Bool = (_modMode == null || _modMode == 'SINGLE MOD');
		
		if(_isSingleMod && Mods.currentModDirectory != null && Mods.currentModDirectory != '')
		{
			try {
				var pack:Dynamic = Mods.getPack();
				if (pack != null && pack.name != null)
					lime.app.Application.current.window.title = pack.name;
				
				var iconPath:String = Paths.modFolders('pack.png');
				if (sys.FileSystem.exists(iconPath))
				{
					var icon = lime.graphics.Image.fromFile(iconPath);
					lime.app.Application.current.window.setIcon(icon);
				}

				if (pack != null && pack.name != null)
					winapi.WindowsCPP.reDefineMainWindowTitle(pack.name);
				Main.applyModWindowColor();
			} catch(e:Dynamic) {
				trace("Error loading mod pack info: " + e);
			}
		}
		#end
		
		var blackScreen:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(blackScreen);
	}
	
	var _pendingState:String = null;
	var _scanDone:Bool = false;
	var _scanFallback:Bool = false;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if(!loadedState)
		{
			loadedState = true;

			#if MODS_ALLOWED
			var _saveForInit = FlxG.save;
			var _initModMode:String = (_saveForInit != null && _saveForInit.data != null && _saveForInit.data.modMode != null) ? _saveForInit.data.modMode : null;
			var _initIsSingle:Bool = (_initModMode == null || _initModMode == 'SINGLE MOD');
			if(_initIsSingle && Mods.currentModDirectory != null && Mods.currentModDirectory != '')
			{
				var modDir = Mods.currentModDirectory;
				var statesDir = Paths.modFolders('$modDir/states/');

				sys.thread.Thread.create(() -> {
					var found:String = null;
					var fallback:Bool = false;

					if(sys.FileSystem.exists(statesDir) && sys.FileSystem.isDirectory(statesDir))
					{
						#if HSCRIPT_ALLOWED
						for(file in sys.FileSystem.readDirectory(statesDir))
						{
							if(file.endsWith('.hx'))
							{
								var stateName = file.substr(0, file.length - 3);
								var fullPath = statesDir + file;
								if(sys.FileSystem.exists(fullPath))
								{
									try {
										var hscript = new psychlua.HScript(null, fullPath, null, false);
										if(hscript.exists('isInitialState'))
										{
											var result = hscript.call('isInitialState', []);
											if(result != null && result.returnValue == true)
											{
												trace('InitialState: Found initial state: $stateName');
												hscript.destroy();
												found = stateName;
												break;
											}
										}
										hscript.destroy();
									} catch(e:Dynamic) {
										trace('InitialState: Error checking $stateName: $e');
									}
								}
							}
						}
						#end
						#if LUA_ALLOWED
						if(found == null)
						{
							for(file in sys.FileSystem.readDirectory(statesDir))
							{
								if(file.endsWith('.lua'))
								{
									var stateName = file.substr(0, file.length - 4);
									var fullPath = statesDir + file;
									if(sys.FileSystem.exists(fullPath))
									{
										try {
											var luaState = new psychlua.LuaStateLoader.LuaState(fullPath, stateName, modDir, null);
											if(luaState.isInitialState)
											{
												trace('InitialState: Found Lua initial state: $stateName');
												luaState.destroy();
												found = stateName;
												break;
											}
											luaState.destroy();
										} catch(e:Dynamic) {
											trace('InitialState: Error checking Lua $stateName: $e');
										}
									}
								}
							}
						}
						#end
					}

					if(found == null)
					{
						#if HSCRIPT_ALLOWED
						var titleHx = backend.HScriptStateLoader.findScriptInDir(statesDir, 'TitleState.hx');
						if(titleHx != null) { found = 'TitleState'; fallback = true; }
						#end
						#if LUA_ALLOWED
						if(found == null)
						{
							var titleLua = psychlua.LuaStateLoader.findScriptInDir(statesDir, 'TitleState.lua');
							if(titleLua != null) { found = 'TitleState'; fallback = true; }
						}
						#end
					}

					_pendingState = found;
					_scanFallback = fallback;
					_scanDone = true;
				});
				return;
			}
			#end

			MusicBeatState.switchState(new states.TitleState());
		}

		#if MODS_ALLOWED
		if(_scanDone)
		{
			_scanDone = false;
			if(_pendingState != null)
			{
				var modDir = Mods.currentModDirectory;
				if(modDir == null || modDir == '')
				{
					if(FlxG.save.data != null && FlxG.save.data.currentMod != null && FlxG.save.data.currentMod != '')
						modDir = FlxG.save.data.currentMod;
				}
				if(modDir != null && modDir != '')
					Mods.currentModDirectory = modDir;
				StateManager.switchState(_pendingState);
			}
			else
				MusicBeatState.switchState(new states.TitleState());
		}
		#end
	}

	static function scanScriptsRecursive(dir:String, ext:String):Array<String>
	{
		var result:Array<String> = [];
		if(!sys.FileSystem.exists(dir) || !sys.FileSystem.isDirectory(dir))
			return result;

		for(entry in sys.FileSystem.readDirectory(dir))
		{
			var full = dir + entry;
			if(sys.FileSystem.isDirectory(full))
			{
				for(found in scanScriptsRecursive(full + '/', ext))
					result.push(found);
			}
			else if(entry.endsWith(ext))
			{
				result.push(full);
			}
		}
		return result;
	}
}