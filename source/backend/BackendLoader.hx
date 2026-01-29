package backend;

#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

class BackendLoader
{
	private static var loadedScripts:Map<String, HScript> = new Map();
	
	public static function getBackendScript(backendName:String):HScript
	{
		if(loadedScripts.exists(backendName))
			return loadedScripts.get(backendName);
		
		#if HSCRIPT_ALLOWED
		#if MODS_ALLOWED
		var savedModDirectory = Mods.currentModDirectory;
		
		if(savedModDirectory == null || savedModDirectory == '')
		{
			var save = FlxG.save;
			if(save != null && save.data != null && save.data.currentMod != null && save.data.currentMod != '')
			{
				savedModDirectory = save.data.currentMod;
			}
		}
		
		if(savedModDirectory != null && savedModDirectory != '')
		{
			var scriptPath = Paths.modFolders('$savedModDirectory/backend/$backendName.hx');
			
			if(sys.FileSystem.exists(scriptPath))
			{
				trace('✓ Loading custom backend script: $scriptPath');
				
				try
				{
					var hscript = new HScript(null, scriptPath, null, false);
					loadedScripts.set(backendName, hscript);
					return hscript;
				}
				catch(e:Dynamic)
				{
					trace('✗ Error loading backend script $backendName: $e');
				}
			}
		}
		#end
		#end
		
		return null;
	}
	
	public static function clearCache():Void
	{
		for(script in loadedScripts)
		{
			if(script != null)
				script.destroy();
		}
		loadedScripts.clear();
	}
}