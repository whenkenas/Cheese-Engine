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
		if(Mods.currentModDirectory != null && Mods.currentModDirectory != '')
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
	
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		
		if(!loadedState)
		{
			loadedState = true;
			
			#if MODS_ALLOWED
			if(Mods.currentModDirectory != null && Mods.currentModDirectory != '')
			{
				var statesDir = Paths.modFolders('${Mods.currentModDirectory}/states/');
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
											StateManager.switchState(stateName);
											return;
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
					for(file in sys.FileSystem.readDirectory(statesDir))
					{
						if(file.endsWith('.lua'))
						{
							var stateName = file.substr(0, file.length - 4);
							var fullPath = statesDir + file;
							
							if(sys.FileSystem.exists(fullPath))
							{
								try {
									var luaState = new psychlua.LuaStateLoader.LuaState(fullPath, stateName, Mods.currentModDirectory, null);
									if(luaState.isInitialState)
									{
										trace('InitialState: Found Lua initial state: $stateName');
										luaState.destroy();
										StateManager.switchState(stateName);
										return;
									}
									luaState.destroy();
								} catch(e:Dynamic) {
									trace('InitialState: Error checking Lua $stateName: $e');
								}
							}
						}
					}
					#end
				}

				#if HSCRIPT_ALLOWED
				var titleScriptPath = Paths.modFolders('${Mods.currentModDirectory}/states/TitleState.hx');
				if(sys.FileSystem.exists(titleScriptPath))
				{
					StateManager.switchState('TitleState');
					return;
				}
				#end
				#if LUA_ALLOWED
				var titleLuaPath = Paths.modFolders('${Mods.currentModDirectory}/states/TitleState.lua');
				if(sys.FileSystem.exists(titleLuaPath))
				{
					StateManager.switchState('TitleState');
					return;
				}
				#end
			}
			#end
			
			MusicBeatState.switchState(new states.TitleState());
		}
	}
}