package psychlua;

import backend.WeekData;
import objects.Character;
import backend.StageData;

import openfl.display.BlendMode;
import Type.ValueType;

import substates.GameOverSubstate;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.util.FlxAxes;

typedef LuaTweenOptions = {
	type:FlxTweenType,
	startDelay:Float,
	onUpdate:Null<String>,
	onStart:Null<String>,
	onComplete:Null<String>,
	loopDelay:Float,
	ease:EaseFunction
}

class LuaUtils
{
	public static final Function_Stop:String = "##PSYCHLUA_FUNCTIONSTOP";
	public static final Function_Continue:String = "##PSYCHLUA_FUNCTIONCONTINUE";
	public static final Function_StopLua:String = "##PSYCHLUA_FUNCTIONSTOPLUA";
	public static final Function_StopHScript:String = "##PSYCHLUA_FUNCTIONSTOPHSCRIPT";
	public static final Function_StopAll:String = "##PSYCHLUA_FUNCTIONSTOPALL";

	public static function getLuaTween(options:Dynamic)
	{
		return (options != null) ? {
			type: getTweenTypeByString(options.type),
			startDelay: options.startDelay,
			onUpdate: options.onUpdate,
			onStart: options.onStart,
			onComplete: options.onComplete,
			loopDelay: options.loopDelay,
			ease: getTweenEaseByString(options.ease)
		} : null;
	}

	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic, allowMaps:Bool = false):Any
	{
		var splitProps:Array<String> = variable.split('[');
		if(splitProps.length > 1)
		{
			var target:Dynamic = null;
			if(MusicBeatState.getVariables().exists(splitProps[0]))
			{
				var retVal:Dynamic = MusicBeatState.getVariables().get(splitProps[0]);
				if(retVal != null)
					target = retVal;
			}
			else target = Reflect.getProperty(instance, splitProps[0]);

			for (i in 1...splitProps.length)
			{
				var j:Dynamic = splitProps[i].substr(0, splitProps[i].length - 1);
				if(i >= splitProps.length-1) //Last array
					target[j] = value;
				else //Anything else
					target = target[j];
			}
			return target;
		}

		if(allowMaps && isMap(instance))
		{
			//trace(instance);
			instance.set(variable, value);
			return value;
		}

		if(instance is MusicBeatState && MusicBeatState.getVariables().exists(variable))
		{
			MusicBeatState.getVariables().set(variable, value);
			return value;
		}
		Reflect.setProperty(instance, variable, value);
		return value;
	}
	public static function getVarInArray(instance:Dynamic, variable:String, allowMaps:Bool = false):Any
	{
		var splitProps:Array<String> = variable.split('[');
		if(splitProps.length > 1)
		{
			var target:Dynamic = null;
			if(MusicBeatState.getVariables().exists(splitProps[0]))
			{
				var retVal:Dynamic = MusicBeatState.getVariables().get(splitProps[0]);
				if(retVal != null)
					target = retVal;
			}
			else
				target = Reflect.getProperty(instance, splitProps[0]);

			for (i in 1...splitProps.length)
			{
				var j:Dynamic = splitProps[i].substr(0, splitProps[i].length - 1);
				target = target[j];
			}
			return target;
		}
		
		if(allowMaps && isMap(instance))
		{
			//trace(instance);
			return instance.get(variable);
		}

		if(instance is MusicBeatState && MusicBeatState.getVariables().exists(variable))
		{
			var retVal:Dynamic = MusicBeatState.getVariables().get(variable);
			if(retVal != null)
				return retVal;
		}
		return Reflect.getProperty(instance, variable);
	}

	public static function getModSetting(saveTag:String, ?modName:String = null)
	{
		#if MODS_ALLOWED
		if(FlxG.save.data.modSettings == null) FlxG.save.data.modSettings = new Map<String, Dynamic>();

		var settings:Map<String, Dynamic> = FlxG.save.data.modSettings.get(modName);
		var path:String = Paths.mods('$modName/data/settings.json');
		if(FileSystem.exists(path))
		{
			if(settings == null || !settings.exists(saveTag))
			{
				if(settings == null) settings = new Map<String, Dynamic>();
				var data:String = File.getContent(path);
				try
				{
					//FunkinLua.luaTrace('getModSetting: Trying to find default value for "$saveTag" in Mod: "$modName"');
					var parsedJson:Dynamic = tjson.TJSON.parse(data);
					for (i in 0...parsedJson.length)
					{
						var sub:Dynamic = parsedJson[i];
						if(sub != null && sub.save != null && !settings.exists(sub.save))
						{
							if(sub.type != 'keybind' && sub.type != 'key')
							{
								if(sub.value != null)
								{
									//FunkinLua.luaTrace('getModSetting: Found unsaved value "${sub.save}" in Mod: "$modName"');
									settings.set(sub.save, sub.value);
								}
							}
							else
							{
								//FunkinLua.luaTrace('getModSetting: Found unsaved keybind "${sub.save}" in Mod: "$modName"');
								settings.set(sub.save, {keyboard: (sub.keyboard != null ? sub.keyboard : 'NONE'), gamepad: (sub.gamepad != null ? sub.gamepad : 'NONE')});
							}
						}
					}
					FlxG.save.data.modSettings.set(modName, settings);
				}
				catch(e:Dynamic)
				{
					var errorTitle = 'Mod name: ' + Mods.currentModDirectory;
					var errorMsg = 'An error occurred: $e';
					#if windows
					lime.app.Application.current.window.alert(errorMsg, errorTitle);
					#end
					trace('$errorTitle - $errorMsg');
				}
			}
		}
		else
		{
			FlxG.save.data.modSettings.remove(modName);
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			PlayState.instance.addTextToDebug('getModSetting: $path could not be found!', FlxColor.RED);
			#else
			FlxG.log.warn('getModSetting: $path could not be found!');
			#end
			return null;
		}

		if(settings.exists(saveTag)) return settings.get(saveTag);
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		PlayState.instance.addTextToDebug('getModSetting: "$saveTag" could not be found inside $modName\'s settings!', FlxColor.RED);
		#else
		FlxG.log.warn('getModSetting: "$saveTag" could not be found inside $modName\'s settings!');
		#end
		#end
		return null;
	}
	
	public static function isMap(variable:Dynamic)
	{
		/*switch(Type.typeof(variable)){
			case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
				return true;
			default:
				return false;
		}*/

		//trace(variable);
		if(variable.exists != null && variable.keyValueIterator != null) return true;
		return false;
	}

	public static function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic, ?allowMaps:Bool = false) {
		var split:Array<String> = variable.split('.');
		if(split.length > 1) {
			var obj:Dynamic = Reflect.getProperty(leArray, split[0]);
			for (i in 1...split.length-1)
				obj = Reflect.getProperty(obj, split[i]);

			leArray = obj;
			variable = split[split.length-1];
		}
		if(allowMaps && isMap(leArray)) leArray.set(variable, value);
		else Reflect.setProperty(leArray, variable, value);
		return value;
	}
	public static function getGroupStuff(leArray:Dynamic, variable:String, ?allowMaps:Bool = false) {
		var split:Array<String> = variable.split('.');
		if(split.length > 1) {
			var obj:Dynamic = Reflect.getProperty(leArray, split[0]);
			for (i in 1...split.length-1)
				obj = Reflect.getProperty(obj, split[i]);

			leArray = obj;
			variable = split[split.length-1];
		}

		if(allowMaps && isMap(leArray)) return leArray.get(variable);
		return Reflect.getProperty(leArray, variable);
	}

	public static function getPropertyLoop(split:Array<String>, ?getProperty:Bool=true, ?allowMaps:Bool = false):Dynamic
	{
		var obj:Dynamic = getObjectDirectly(split[0]);
		var end = split.length;
		if(getProperty) end = split.length-1;

		for (i in 1...end) obj = getVarInArray(obj, split[i], allowMaps);
		return obj;
	}

	public static function getObjectDirectly(objectName:String, ?allowMaps:Bool = false):Dynamic
	{
		switch(objectName)
		{
			case 'this' | 'instance' | 'game':
				return PlayState.instance;
			
			default:
				var obj:Dynamic = MusicBeatState.getVariables().get(objectName);
				if(obj == null) obj = getVarInArray(MusicBeatState.getState(), objectName, allowMaps);
				return obj;
		}
	}
	
	public static function isOfTypes(value:Any, types:Array<Dynamic>)
	{
		for (type in types)
		{
			if(Std.isOfType(value, type)) return true;
		}
		return false;
	}
	public static function isLuaSupported(value:Any):Bool {
		return (value == null || isOfTypes(value, [Bool, Int, Float, String, Array]) || Type.typeof(value) == ValueType.TObject);
	}
	
	public static function getTargetInstance()
	{
		if(PlayState.instance != null)
		{
			var currentState = MusicBeatState.getState();
			if(currentState == PlayState.instance)
				return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
		}
		return MusicBeatState.getState();
	}

	public static inline function getLowestCharacterGroup():FlxSpriteGroup
	{
		var stageData:StageFile = StageData.getStageFile(PlayState.SONG.stage);
		var group:FlxSpriteGroup = (stageData.hide_girlfriend ? PlayState.instance.boyfriendGroup : PlayState.instance.gfGroup);

		var pos:Int = PlayState.instance.members.indexOf(group);

		var newPos:Int = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);
		if(newPos < pos)
		{
			group = PlayState.instance.boyfriendGroup;
			pos = newPos;
		}
		
		newPos = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);
		if(newPos < pos)
		{
			group = PlayState.instance.dadGroup;
			pos = newPos;
		}
		return group;
	}
	
	public static function addAnimByIndices(obj:String, name:String, prefix:String, indices:Any = null, framerate:Float = 24, loop:Bool = false)
	{
		var obj:FlxSprite = cast LuaUtils.getObjectDirectly(obj);
		if(obj != null && obj.animation != null)
		{
			if(indices == null)
				indices = [0];
			else if(Std.isOfType(indices, String))
			{
				var strIndices:Array<String> = cast (indices, String).trim().split(',');
				var myIndices:Array<Int> = [];
				for (i in 0...strIndices.length) {
					myIndices.push(Std.parseInt(strIndices[i]));
				}
				indices = myIndices;
			}

			if(prefix != null) obj.animation.addByIndices(name, prefix, indices, '', framerate, loop);
			else obj.animation.add(name, indices, framerate, loop);

			if(obj.animation.curAnim == null)
			{
				var dyn:Dynamic = cast obj;
				if(dyn.playAnim != null) dyn.playAnim(name, true);
				else dyn.animation.play(name, true);
			}
			return true;
		}
		return false;
	}
	
	public static function loadFrames(spr:FlxSprite, image:String, spriteType:String)
	{
		switch(spriteType.toLowerCase().replace(' ', ''))
		{
			//case "texture" | "textureatlas" | "tex":
				//spr.frames = AtlasFrameMaker.construct(image);

			//case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
				//spr.frames = AtlasFrameMaker.construct(image, null, true);

			case 'aseprite', 'ase', 'json', 'jsoni8':
				spr.frames = Paths.getAsepriteAtlas(image);

			case "packer", 'packeratlas', 'pac':
				spr.frames = Paths.getPackerAtlas(image);

			case 'sparrow', 'sparrowatlas', 'sparrowv2':
				spr.frames = Paths.getSparrowAtlas(image);

			default:
				spr.frames = Paths.getAtlas(image);
		}
	}

	public static function destroyObject(tag:String) {
		var variables = MusicBeatState.getVariables();
		var obj:FlxSprite = variables.get(tag);
		if(obj == null || obj.destroy == null)
			return;

		LuaUtils.getTargetInstance().remove(obj, true);
		obj.destroy();
		variables.remove(tag);
	}

	public static function cancelTween(tag:String) {
		if(!tag.startsWith('tween_')) tag = 'tween_' + LuaUtils.formatVariable(tag);
		var variables = MusicBeatState.getVariables();
		var twn:FlxTween = variables.get(tag);
		if(twn != null)
		{
			twn.cancel();
			twn.destroy();
			variables.remove(tag);
		}
	}

	public static function cancelTimer(tag:String) {
		if(!tag.startsWith('timer_')) tag = 'timer_' + LuaUtils.formatVariable(tag);
		var variables = MusicBeatState.getVariables();
		var tmr:FlxTimer = variables.get(tag);
		if(tmr != null)
		{
			tmr.cancel();
			tmr.destroy();
			variables.remove(tag);
		}
	}

	public static function formatVariable(tag:String)
		return tag.trim().replace(' ', '_').replace('.', '');

	public static function tweenPrepare(tag:String, vars:String) {
		if(tag != null) cancelTween(tag);
		var variables:Array<String> = vars.split('.');
		var sexyProp:Dynamic = LuaUtils.getObjectDirectly(variables[0]);
		if(variables.length > 1) sexyProp = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(variables), variables[variables.length-1]);
		return sexyProp;
	}

	public static function getBuildTarget():String
	{
		#if windows
		#if x86_BUILD
		return 'windows_x86';
		#else
		return 'windows';
		#end
		#elseif linux
		return 'linux';
		#elseif mac
		return 'mac';
		#elseif html5
		return 'browser';
		#elseif android
		return 'android';
		#elseif switch
		return 'switch';
		#else
		return 'unknown';
		#end
	}

	//buncho string stuffs
	public static function getTweenTypeByString(?type:String = '') {
		switch(type.toLowerCase().trim())
		{
			case 'backward': return FlxTweenType.BACKWARD;
			case 'looping'|'loop': return FlxTweenType.LOOPING;
			case 'persist': return FlxTweenType.PERSIST;
			case 'pingpong': return FlxTweenType.PINGPONG;
		}
		return FlxTweenType.ONESHOT;
	}

	public static function getTweenEaseByString(?ease:String = '') {
		switch(ease.toLowerCase().trim()) {
			case 'backin': return FlxEase.backIn;
			case 'backinout': return FlxEase.backInOut;
			case 'backout': return FlxEase.backOut;
			case 'bouncein': return FlxEase.bounceIn;
			case 'bounceinout': return FlxEase.bounceInOut;
			case 'bounceout': return FlxEase.bounceOut;
			case 'circin': return FlxEase.circIn;
			case 'circinout': return FlxEase.circInOut;
			case 'circout': return FlxEase.circOut;
			case 'cubein': return FlxEase.cubeIn;
			case 'cubeinout': return FlxEase.cubeInOut;
			case 'cubeout': return FlxEase.cubeOut;
			case 'elasticin': return FlxEase.elasticIn;
			case 'elasticinout': return FlxEase.elasticInOut;
			case 'elasticout': return FlxEase.elasticOut;
			case 'expoin': return FlxEase.expoIn;
			case 'expoinout': return FlxEase.expoInOut;
			case 'expoout': return FlxEase.expoOut;
			case 'quadin': return FlxEase.quadIn;
			case 'quadinout': return FlxEase.quadInOut;
			case 'quadout': return FlxEase.quadOut;
			case 'quartin': return FlxEase.quartIn;
			case 'quartinout': return FlxEase.quartInOut;
			case 'quartout': return FlxEase.quartOut;
			case 'quintin': return FlxEase.quintIn;
			case 'quintinout': return FlxEase.quintInOut;
			case 'quintout': return FlxEase.quintOut;
			case 'sinein': return FlxEase.sineIn;
			case 'sineinout': return FlxEase.sineInOut;
			case 'sineout': return FlxEase.sineOut;
			case 'smoothstepin': return FlxEase.smoothStepIn;
			case 'smoothstepinout': return FlxEase.smoothStepInOut;
			case 'smoothstepout': return FlxEase.smoothStepOut;
			case 'smootherstepin': return FlxEase.smootherStepIn;
			case 'smootherstepinout': return FlxEase.smootherStepInOut;
			case 'smootherstepout': return FlxEase.smootherStepOut;
		}
		return FlxEase.linear;
	}

	public static function blendModeFromString(blend:String):BlendMode {
		switch(blend.toLowerCase().trim()) {
			case 'add': return ADD;
			case 'alpha': return ALPHA;
			case 'darken': return DARKEN;
			case 'difference': return DIFFERENCE;
			case 'erase': return ERASE;
			case 'hardlight': return HARDLIGHT;
			case 'invert': return INVERT;
			case 'layer': return LAYER;
			case 'lighten': return LIGHTEN;
			case 'multiply': return MULTIPLY;
			case 'overlay': return OVERLAY;
			case 'screen': return SCREEN;
			case 'shader': return SHADER;
			case 'subtract': return SUBTRACT;
		}
		return NORMAL;
	}
	
	public static function typeToString(type:Int):String {
		#if LUA_ALLOWED
		switch(type) {
			case Lua.LUA_TBOOLEAN: return "boolean";
			case Lua.LUA_TNUMBER: return "number";
			case Lua.LUA_TSTRING: return "string";
			case Lua.LUA_TTABLE: return "table";
			case Lua.LUA_TFUNCTION: return "function";
		}
		if (type <= Lua.LUA_TNIL) return "nil";
		#end
		return "unknown";
	}

	public static function cameraFromString(cam:String):FlxCamera {
		switch(cam.toLowerCase()) {
			case 'camgame' | 'game': return PlayState.instance.camGame;
			case 'camhud' | 'hud': return PlayState.instance.camHUD;
			case 'camother' | 'other': return PlayState.instance.camOther;
		}
		var camera:FlxCamera = MusicBeatState.getVariables().get(cam);
		if (camera == null || !Std.isOfType(camera, FlxCamera)) camera = PlayState.instance.camGame;
		return camera;
	}

	#if LUA_ALLOWED
	public static function registerBasicCallbacks(lua:llua.State, instance:Dynamic, ?callLua:String->Array<Dynamic>->Dynamic):Void
	{
		Lua_helper.add_callback(lua, "setProperty", function(variable:String, value:Dynamic) {
			var split:Array<String> = variable.split('.');
			if(split.length > 1) {
				var obj:Dynamic = _getTransitionObject(split[0], instance);
				for(i in 1...split.length - 1)
					obj = getVarInArray(obj, split[i]);
				setVarInArray(obj, split[split.length - 1], value);
			} else {
				setVarInArray(instance, variable, value);
			}
			return value;
		});
		Lua_helper.add_callback(lua, "getProperty", function(variable:String) {
			var split:Array<String> = variable.split('.');
			if(split.length > 1) {
				var obj:Dynamic = _getTransitionObject(split[0], instance);
				for(i in 1...split.length - 1)
					obj = getVarInArray(obj, split[i]);
				return getVarInArray(obj, split[split.length - 1]);
			}
			return getVarInArray(instance, variable);
		});
		Lua_helper.add_callback(lua, "getPropertyFromClass", function(className:String, variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:Dynamic = Type.resolveClass(className);
			if(obj != null)
				for(i in 0...split.length)
					obj = getVarInArray(obj, split[i]);
			return obj;
		});
		Lua_helper.add_callback(lua, "setPropertyFromClass", function(className:String, variable:String, value:Dynamic) {
			var split:Array<String> = variable.split('.');
			var obj:Dynamic = Type.resolveClass(className);
			if(obj != null) {
				if(split.length > 1) {
					var lastObj:Dynamic = obj;
					for(i in 0...split.length - 1)
						lastObj = getVarInArray(lastObj, split[i]);
					setVarInArray(lastObj, split[split.length - 1], value);
				} else {
					setVarInArray(obj, variable, value);
				}
			}
			return value;
		});
		Lua_helper.add_callback(lua, "callMethod", function(obj:Dynamic, funcToRun:String, ?args:Array<Dynamic> = null) {
			if(args == null) args = [];
			var object:Dynamic = obj == null ? instance : _getTransitionObject(obj, instance);
			if(object != null && funcToRun != null) {
				var func:Dynamic = Reflect.getProperty(object, funcToRun);
				if(func != null) return Reflect.callMethod(object, func, args);
			}
			return null;
		});
		Lua_helper.add_callback(lua, "callMethodFromClass", function(className:String, funcToRun:String, ?args:Array<Dynamic> = null) {
			if(args == null) args = [];
			var obj:Dynamic = Type.resolveClass(className);
			if(obj != null && funcToRun != null) {
				var func:Dynamic = Reflect.getProperty(obj, funcToRun);
				if(func != null) return Reflect.callMethod(obj, func, args);
			}
			return null;
		});

		Lua_helper.add_callback(lua, "makeLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			destroyObject(tag);
			var leSprite:psychlua.ModchartSprite = new psychlua.ModchartSprite(x, y);
			if(image != null && image.length > 0)
				leSprite.loadGraphic(Paths.image(image));
			MusicBeatState.getVariables().set(tag, leSprite);
			leSprite.active = true;
		});
		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = 'auto') {
			tag = tag.replace('.', '');
			destroyObject(tag);
			var leSprite:psychlua.ModchartSprite = new psychlua.ModchartSprite(x, y);
			if(image != null && image.length > 0)
				loadFrames(leSprite, image, spriteType);
			MusicBeatState.getVariables().set(tag, leSprite);
		});
		Lua_helper.add_callback(lua, "makeGraphic", function(tag:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF') {
			var spr:FlxSprite = cast _getTransitionObject(tag, instance);
			if(spr != null) spr.makeGraphic(width, height, CoolUtil.colorFromString(color));
		});
		Lua_helper.add_callback(lua, "loadGraphic", function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = cast _getTransitionObject(split[0], instance);
			if(split.length > 1)
				spr = cast getVarInArray(getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && image != null && image.length > 0)
				spr.loadGraphic(Paths.image(image), gridX != 0 || gridY != 0, gridX, gridY);
		});
		Lua_helper.add_callback(lua, "loadFrames", function(variable:String, image:String, spriteType:String = 'auto') {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = cast _getTransitionObject(split[0], instance);
			if(split.length > 1)
				spr = cast getVarInArray(getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && image != null && image.length > 0)
				loadFrames(spr, image, spriteType);
		});
		Lua_helper.add_callback(lua, "addObject", function(tag:String) {
			var obj:FlxBasic = cast _getTransitionObject(tag, instance);
			if(obj != null) instance.add(obj);
		});
		Lua_helper.add_callback(lua, "removeObject", function(tag:String, ?destroy:Bool = true) {
			var variables = MusicBeatState.getVariables();
			var obj:FlxSprite = cast variables.get(tag);
			if(obj == null || obj.destroy == null) return;
			instance.remove(obj, true);
			if(destroy) {
				obj.destroy();
				variables.remove(tag);
			}
		});

		Lua_helper.add_callback(lua, "screenCenter", function(obj:String, pos:String = 'xy') {
			var split:Array<String> = obj.split('.');
			var spr:FlxObject = cast _getTransitionObject(split[0], instance);
			if(split.length > 1)
				spr = cast getVarInArray(getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) {
				switch(pos.trim().toLowerCase()) {
					case 'x': spr.screenCenter(FlxAxes.X);
					case 'y': spr.screenCenter(FlxAxes.Y);
					default:  spr.screenCenter(FlxAxes.XY);
				}
			}
		});
		Lua_helper.add_callback(lua, "setGraphicSize", function(obj:String, x:Float, y:Float = 0, updateHitbox:Bool = true) {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = cast _getTransitionObject(split[0], instance);
			if(split.length > 1)
				spr = cast getVarInArray(getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) {
				spr.setGraphicSize(x, y);
				if(updateHitbox) spr.updateHitbox();
			}
		});
		Lua_helper.add_callback(lua, "setScrollFactor", function(obj:String, scrollX:Float, scrollY:Float) {
			var split:Array<String> = obj.split('.');
			var spr:FlxObject = cast _getTransitionObject(split[0], instance);
			if(split.length > 1)
				spr = cast getVarInArray(getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) spr.scrollFactor.set(scrollX, scrollY);
		});
		Lua_helper.add_callback(lua, "updateHitbox", function(obj:String) {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = cast _getTransitionObject(split[0], instance);
			if(split.length > 1)
				spr = cast getVarInArray(getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) spr.updateHitbox();
		});

		Lua_helper.add_callback(lua, "addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Float = 24, loop:Bool = true) {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = cast _getTransitionObject(split[0], instance);
			if(split.length > 1)
				spr = cast getVarInArray(getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && spr.animation != null) {
				spr.animation.addByPrefix(name, prefix, framerate, loop);
				if(spr.animation.curAnim == null) spr.animation.play(name, true);
			}
		});
		Lua_helper.add_callback(lua, "addAnimation", function(obj:String, name:String, frames:Array<Int>, framerate:Float = 24, loop:Bool = true) {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = cast _getTransitionObject(split[0], instance);
			if(split.length > 1)
				spr = cast getVarInArray(getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && spr.animation != null) {
				spr.animation.add(name, frames, framerate, loop);
				if(spr.animation.curAnim == null) spr.animation.play(name, true);
			}
		});
		Lua_helper.add_callback(lua, "addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:String, framerate:Float = 24, loop:Bool = false) {
			addAnimByIndices(obj, name, prefix, indices, framerate, loop);
		});
		Lua_helper.add_callback(lua, "playAnim", function(obj:String, name:String, forced:Bool = false, ?reversed:Bool = false, ?frame:Int = 0) {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = cast _getTransitionObject(split[0], instance);
			if(split.length > 1)
				spr = cast getVarInArray(getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && spr.animation != null)
				spr.animation.play(name, forced, reversed, frame);
		});

		Lua_helper.add_callback(lua, "doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return _transitionTween(tag, vars, {x: value}, duration, ease, instance, callLua);
		});
		Lua_helper.add_callback(lua, "doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return _transitionTween(tag, vars, {y: value}, duration, ease, instance, callLua);
		});
		Lua_helper.add_callback(lua, "doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return _transitionTween(tag, vars, {angle: value}, duration, ease, instance, callLua);
		});
		Lua_helper.add_callback(lua, "doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return _transitionTween(tag, vars, {alpha: value}, duration, ease, instance, callLua);
		});
		Lua_helper.add_callback(lua, "doTween", function(tag:String, vars:String, tweenValue:Dynamic, duration:Float, ?ease:String = 'linear') {
			return _transitionTween(tag, vars, tweenValue, duration, ease, instance, callLua);
		});
		Lua_helper.add_callback(lua, "cancelTween", function(tag:String) cancelTween(tag));

		Lua_helper.add_callback(lua, "runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			cancelTimer(tag);
			var variables = MusicBeatState.getVariables();
			var originalTag:String = tag;
			tag = formatVariable('timer_$tag');
			variables.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if(tmr.finished) variables.remove(tag);
				if(callLua != null) callLua('onTimerCompleted', [originalTag, tmr.loops, tmr.loopsLeft]);
			}, loops));
			return tag;
		});
		Lua_helper.add_callback(lua, "cancelTimer", function(tag:String) cancelTimer(tag));

		Lua_helper.add_callback(lua, "playSound", function(sound:String, ?volume:Float = 1, ?tag:String = null, ?loop:Bool = false) {
			if(tag != null && tag.length > 0) {
				var originalTag:String = tag;
				tag = formatVariable('sound_$tag');
				var variables = MusicBeatState.getVariables();
				var oldSnd = variables.get(tag);
				if(oldSnd != null) {
					oldSnd.stop();
					oldSnd.destroy();
				}
				variables.set(tag, FlxG.sound.play(Paths.sound(sound), volume, loop, null, true, function() {
					variables.remove(tag);
					if(!loop && callLua != null) callLua('onSoundFinished', [originalTag]);
				}));
			} else {
				FlxG.sound.play(Paths.sound(sound), volume, loop);
			}
		});
		Lua_helper.add_callback(lua, "playMusic", function(sound:String, ?volume:Float = 1, ?loop:Bool = false) {
			FlxG.sound.playMusic(Paths.music(sound), volume, loop);
		});
	}

	static function _transitionTween(tag:String, vars:String, tweenValue:Dynamic, duration:Float, ease:String, instance:Dynamic, ?callLua:String->Array<Dynamic>->Dynamic):Dynamic
	{
		if(tag != null) cancelTween(tag);
		var varsSplit:Array<String> = vars.split('.');
		var target:Dynamic = _getTransitionObject(varsSplit[0], instance);
		if(varsSplit.length > 1) {
			for(i in 1...varsSplit.length - 1)
				target = getVarInArray(target, varsSplit[i]);
			target = getVarInArray(target, varsSplit[varsSplit.length - 1]);
		}
		if(target != null) {
			var originalTag:String = tag;
			tag = formatVariable('tween_$tag');
			var variables = MusicBeatState.getVariables();
			variables.set(tag, FlxTween.tween(target, tweenValue, duration, {
				ease: getTweenEaseByString(ease),
				onComplete: function(twn:FlxTween) {
					variables.remove(tag);
					if(callLua != null) callLua('onTweenCompleted', [originalTag, vars]);
				}
			}));
			return originalTag;
		}
		return null;
	}

	static function _getTransitionObject(name:String, instance:Dynamic):Dynamic
	{
		switch(name)
		{
			case 'this' | 'instance' | 'game':
				return instance;
			default:
				var obj:Dynamic = MusicBeatState.getVariables().get(name);
				if(obj == null) obj = Reflect.getProperty(instance, name);
				return obj;
		}
	}
	#end
}