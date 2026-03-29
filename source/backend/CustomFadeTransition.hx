package backend;

import flixel.util.FlxGradient;
import flixel.util.FlxAxes;

class CustomFadeTransition extends MusicBeatSubstate
{
	public static var finishCallback:Void->Void;
	var isTransIn:Bool = false;
	public var transBlack:FlxSprite;
	public var transGradient:FlxSprite;
	var duration:Float;
	var _scriptTimeout:Float = 0;
	var _closeRequested:Bool = false;
	var _closing:Bool = false;

	#if HSCRIPT_ALLOWED
	var hscript:psychlua.HScript = null;
	#end

	#if LUA_ALLOWED
	var lua:llua.State = null;
	var luaClosed:Bool = false;

	function luaSet(variable:String, data:Dynamic)
	{
		if(lua == null) return;
		llua.Convert.toLua(lua, data);
		llua.Lua.setglobal(lua, variable);
	}

	function luaCall(func:String, args:Array<Dynamic>):Dynamic
	{
		if(luaClosed || lua == null) return null;
		llua.Lua.getglobal(lua, func);
		if(llua.Lua.type(lua, -1) != llua.Lua.LUA_TFUNCTION)
		{
			llua.Lua.pop(lua, 1);
			return null;
		}
		for(arg in args) llua.Convert.toLua(lua, arg);
		llua.Lua.pcall(lua, args.length, 1, 0);
		var result:Dynamic = llua.Convert.fromLua(lua, -1);
		llua.Lua.pop(lua, 1);
		return result;
	}

	function luaFuncExists(func:String):Bool
	{
		if(lua == null) return false;
		llua.Lua.getglobal(lua, func);
		var type:Int = llua.Lua.type(lua, -1);
		llua.Lua.pop(lua, 1);
		return (type == llua.Lua.LUA_TFUNCTION);
	}

	function luaDestroy()
	{
		luaClosed = true;
		if(lua != null)
		{
			llua.Lua.close(lua);
			lua = null;
		}
	}
	#end

	public function new(duration:Float, isTransIn:Bool)
	{
		this.duration = duration;
		this.isTransIn = isTransIn;
		super();
	}

	override function create()
	{
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
		var width:Int = Std.int(FlxG.width / Math.max(camera.zoom, 0.001));
		var height:Int = Std.int(FlxG.height / Math.max(camera.zoom, 0.001));

		transGradient = FlxGradient.createGradientFlxSprite(1, height, (isTransIn ? [0x0, FlxColor.BLACK] : [FlxColor.BLACK, 0x0]));
		transGradient.scale.x = width;
		transGradient.updateHitbox();
		transGradient.scrollFactor.set();
		transGradient.screenCenter(FlxAxes.X);
		add(transGradient);

		transBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		transBlack.scale.set(width, height + 400);
		transBlack.updateHitbox();
		transBlack.scrollFactor.set();
		transBlack.screenCenter(FlxAxes.X);
		add(transBlack);

		if(isTransIn)
			transGradient.y = transBlack.y - transBlack.height;
		else
			transGradient.y = -transGradient.height;

		super.create();

		#if HSCRIPT_ALLOWED
		var scriptPath:String = Paths.modFolders('data/CustomTransition.hx');
		if(!sys.FileSystem.exists(scriptPath))
			scriptPath = Paths.modFolders('data/CustomFadeTransition.hx');
		if(sys.FileSystem.exists(scriptPath))
		{
			try
			{
				hscript = new psychlua.HScript(null, scriptPath);
				hscript.set('isTransIn', isTransIn);
				hscript.set('duration', duration);
				hscript.set('screenWidth', FlxG.width);
				hscript.set('screenHeight', FlxG.height);
				hscript.set('game', this);
				hscript.set('closeTransition', function() _closeRequested = true);
				hscript.set('setScriptTimeout', function(time:Float) _scriptTimeout = time);
				if(hscript.exists('onCreate')) hscript.call('onCreate');
			}
			catch(e:Dynamic)
			{
				trace('CustomTransition HScript error: $e');
				hscript = null;
			}
		}
		#end

		#if LUA_ALLOWED
		var hasHScript:Bool = false;
		#if HSCRIPT_ALLOWED
		hasHScript = (hscript != null);
		#end
		if(!hasHScript)
		{
			var luaPath:String = Paths.modFolders('data/CustomTransition.lua');
			if(!sys.FileSystem.exists(luaPath))
				luaPath = Paths.modFolders('data/CustomFadeTransition.lua');
			if(sys.FileSystem.exists(luaPath))
			{
				lua = llua.LuaL.newstate();
				llua.LuaL.openlibs(lua);
				luaSet('isTransIn', isTransIn);
				luaSet('duration', duration);
				luaSet('screenWidth', FlxG.width);
				luaSet('screenHeight', FlxG.height);
				psychlua.LuaUtils.registerBasicCallbacks(lua, this, luaCall);
				llua.Lua_helper.add_callback(lua, "closeTransition", function() _closeRequested = true);
				llua.Lua_helper.add_callback(lua, "setScriptTimeout", function(time:Float) _scriptTimeout = time);
				var result:Dynamic = llua.LuaL.dofile(lua, luaPath);
				var resultStr:String = llua.Lua.tostring(lua, result);
				if(resultStr != null && result != 0)
				{
					trace('CustomTransition Lua error: $resultStr');
					luaDestroy();
				}
				else if(luaFuncExists('onCreate'))
					luaCall('onCreate', []);
			}
		}
		#end
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var hasScript:Bool = false;
		#if HSCRIPT_ALLOWED
		if(hscript != null)
		{
			hasScript = true;
			if(hscript.exists('onUpdate')) hscript.call('onUpdate', [elapsed]);
		}
		#end
		#if LUA_ALLOWED
		if(lua != null)
		{
			hasScript = true;
			if(luaFuncExists('onUpdate')) luaCall('onUpdate', [elapsed]);
		}
		#end

		if(_closeRequested)
		{
			close();
			return;
		}

		if(hasScript)
		{
			if(_scriptTimeout > 0)
			{
				_scriptTimeout -= elapsed;
				if(_scriptTimeout <= 0) close();
			}
			return;
		}

		final height:Float = FlxG.height * Math.max(camera.zoom, 0.001);
		final targetPos:Float = transGradient.height + 50 * Math.max(camera.zoom, 0.001);
		if(duration > 0)
			transGradient.y += (height + targetPos) * elapsed / duration;
		else
			transGradient.y = targetPos * elapsed;

		if(isTransIn)
			transBlack.y = transGradient.y + transGradient.height;
		else
			transBlack.y = transGradient.y - transBlack.height;

		if(transGradient.y >= targetPos)
			close();
	}

	override function close():Void
	{
		if(_closing) return;
		_closing = true;

		#if HSCRIPT_ALLOWED
		if(hscript != null)
		{
			if(hscript.exists('onClose')) hscript.call('onClose');
			hscript.destroy();
			hscript = null;
		}
		#end
		#if LUA_ALLOWED
		if(lua != null)
		{
			if(luaFuncExists('onClose')) luaCall('onClose', []);
			luaDestroy();
		}
		#end

		super.close();

		if(finishCallback != null)
		{
			finishCallback();
			finishCallback = null;
		}
	}
}