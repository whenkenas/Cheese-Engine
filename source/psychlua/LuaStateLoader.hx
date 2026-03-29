package psychlua;

#if LUA_ALLOWED

import flixel.FlxState;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;

import psychlua.LuaUtils;
import psychlua.LuaUtils.LuaTweenOptions;
import psychlua.ModchartSprite;

import flixel.input.gamepad.FlxGamepadInputID;

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
import psychlua.HScript;
import psychlua.HScript.HScriptInfos;
#end

class LuaState extends MusicBeatState
{
	public var lua:State = null;
	public var stateName:String;
	public var modDirectory:String;
	public var oldStickers:Array<substates.StickerSubState.StickerSprite>;
	public var isInitialState:Bool = false;
	public var closed:Bool = false;
	public var lastCalledFunction:String = '';

	#if HSCRIPT_ALLOWED
	public var hscript:HScript = null;
	#end

	public function new(scriptPath:String, name:String, ?modDir:String, ?stickers:Array<substates.StickerSubState.StickerSprite>)
	{
		super();
		this.stateName = name;
		this.modDirectory = modDir;
		this.oldStickers = stickers;

		if(modDirectory != null && modDirectory != '')
			Mods.currentModDirectory = modDirectory;

		lua = LuaL.newstate();
		LuaL.openlibs(lua);

		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('Function_StopLua', LuaUtils.Function_StopLua);
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);
		set('buildTarget', LuaUtils.getBuildTarget());
		set('currentModDirectory', Mods.currentModDirectory);
		set('stateName', name);

		registerCallbacks();

		try {
			var result:Dynamic = LuaL.dofile(lua, scriptPath);
			var resultStr:String = Lua.tostring(lua, result);
			if(resultStr != null && result != 0) {
				trace('LuaState: Error loading $scriptPath\n$resultStr');
				lua = null;
				return;
			}
		} catch(e:Dynamic) {
			trace('LuaState: Exception loading $scriptPath: $e');
			lua = null;
			return;
		}

		Lua.getglobal(lua, 'isInitialState');
		if(Lua.type(lua, -1) == Lua.LUA_TFUNCTION) {
			var status:Int = Lua.pcall(lua, 0, 1, 0);
			if(status == Lua.LUA_OK) {
				var result:Dynamic = cast Convert.fromLua(lua, -1);
				if(result == true) isInitialState = true;
			}
			Lua.pop(lua, 1);
		} else {
			Lua.pop(lua, 1);
		}
	}

	function registerCallbacks()
	{
		Lua_helper.add_callback(lua, "switchState", function(stateName:String) {
			backend.StateManager.switchState(stateName);
		});

		Lua_helper.add_callback(lua, "isMusicPlaying", function() {
			return FlxG.sound.music != null && FlxG.sound.music.playing;
		});

		Lua_helper.add_callback(lua, "getScore", function(songName:String, diffIndex:Int) {
			return backend.Highscore.getScore(songName, diffIndex);
		});

		Lua_helper.add_callback(lua, "getSongsFromWeek", function(weekName:String) {
			var result:Array<String> = [];
			#if MODS_ALLOWED
			var weekPath = Paths.mods(Mods.currentModDirectory + '/weeks/' + weekName + '.json');
			if(FileSystem.exists(weekPath)) {
				var weekData:Dynamic = haxe.Json.parse(sys.io.File.getContent(weekPath));
				for(songData in cast(weekData.songs, Array<Dynamic>)) {
					result.push(songData[0]);
				}
			}
			#end
			return result;
		});

		Lua_helper.add_callback(lua, "getDifficulties", function() {
			return backend.Difficulty.list;
		});

		Lua_helper.add_callback(lua, "getDifficultyName", function(index:Int) {
			if(index < 0 || index >= backend.Difficulty.list.length) return 'normal';
			return backend.Difficulty.list[index];
		});

		Lua_helper.add_callback(lua, "loadSong", function(songName:String, ?difficulty:String = 'normal') {
			Mods.currentModDirectory = Mods.currentModDirectory;
			var chart = backend.Song.loadFromJson(songName.toLowerCase(), songName.toLowerCase());
			if(chart != null) {
				states.PlayState.SONG = chart;
				states.PlayState.isStoryMode = false;
				var diffIdx = backend.Difficulty.list.indexOf(difficulty);
				states.PlayState.storyDifficulty = diffIdx < 0 ? 0 : diffIdx;
				states.PlayState.previousState = 'FreeplayState';
			}
		});
		
        Lua_helper.add_callback(lua, "lerp", function(a:Float, b:Float, t:Float) return a + (b - a) * t);
		Lua_helper.add_callback(lua, "flxLerp", function(a:Float, b:Float, t:Float) return flixel.math.FlxMath.lerp(a, b, t));
		Lua_helper.add_callback(lua, "setCameraZoom", function(zoom:Float) FlxG.camera.zoom = zoom);
		Lua_helper.add_callback(lua, "getCameraZoom", function() return FlxG.camera.zoom);
		Lua_helper.add_callback(lua, "setCameraScrollX", function(x:Float) FlxG.camera.scroll.x = x);
		Lua_helper.add_callback(lua, "setCameraScrollY", function(y:Float) FlxG.camera.scroll.y = y);
		Lua_helper.add_callback(lua, "setMouseVisible", function(visible:Bool) FlxG.mouse.visible = visible);
		Lua_helper.add_callback(lua, "getMouseVisible", function() return FlxG.mouse.visible);
		Lua_helper.add_callback(lua, "resetState", function() {
			MusicBeatState.resetState();
		});
		Lua_helper.add_callback(lua, "openSubState", function(substate:Dynamic) {
			if(Std.isOfType(substate, String)) {
				var shortNames:Map<String, String> = [
					'EditorPickerSubstate' => 'states.editors.EditorPickerSubstate'
				];
				var resolved:String = shortNames.exists(substate) ? shortNames.get(substate) : substate;
				var cls = Type.resolveClass(resolved);
				if(cls != null) openSubState(Type.createInstance(cls, []));
			} else {
				openSubState(substate);
			}
		});
		Lua_helper.add_callback(lua, "closeSubState", function() {
			closeSubState();
		});

		Lua_helper.add_callback(lua, "setVar", function(varName:String, value:Dynamic) {
			MusicBeatState.getVariables().set(varName, value);
			return value;
		});
		Lua_helper.add_callback(lua, "getVar", function(varName:String) {
			return MusicBeatState.getVariables().get(varName);
		});

		Lua_helper.add_callback(lua, "setProperty", function(variable:String, value:Dynamic) {
			var split:Array<String> = variable.split('.');
			if(split.length > 1)
				LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1], value);
			else
				LuaUtils.setVarInArray(MusicBeatState.getState(), variable, value);
			return value;
		});
		Lua_helper.add_callback(lua, "getProperty", function(variable:String) {
			var split:Array<String> = variable.split('.');
			if(split.length > 1)
				return LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			return LuaUtils.getVarInArray(MusicBeatState.getState(), variable);
		});

		Lua_helper.add_callback(lua, "makeLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
				leSprite.loadGraphic(Paths.image(image));
			MusicBeatState.getVariables().set(tag, leSprite);
			leSprite.active = true;
		});
		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = 'auto') {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
				LuaUtils.loadFrames(leSprite, image, spriteType);
			MusicBeatState.getVariables().set(tag, leSprite);
		});
		Lua_helper.add_callback(lua, "addLuaSprite", function(tag:String, ?inFront:Bool = true) {
			var mySprite:FlxSprite = MusicBeatState.getVariables().get(tag);
			if(mySprite == null) return;
			add(mySprite);
		});
		Lua_helper.add_callback(lua, "removeLuaSprite", function(tag:String, destroy:Bool = true) {
			var obj:FlxSprite = LuaUtils.getObjectDirectly(tag);
			if(obj == null || obj.destroy == null) return;
			remove(obj, true);
			if(destroy) {
				MusicBeatState.getVariables().remove(tag);
				obj.destroy();
			}
		});
		Lua_helper.add_callback(lua, "luaSpriteExists", function(tag:String) {
			var obj = MusicBeatState.getVariables().get(tag);
			return (obj != null && Std.isOfType(obj, ModchartSprite));
		});
		Lua_helper.add_callback(lua, "makeGraphic", function(obj:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF') {
			var spr:FlxSprite = LuaUtils.getObjectDirectly(obj);
			if(spr != null) spr.makeGraphic(width, height, CoolUtil.colorFromString(color));
		});
		Lua_helper.add_callback(lua, "loadGraphic", function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			var animated = gridX != 0 || gridY != 0;
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && image != null && image.length > 0)
				spr.loadGraphic(Paths.image(image), animated, gridX, gridY);
		});
		Lua_helper.add_callback(lua, "loadFrames", function(variable:String, image:String, spriteType:String = 'auto') {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && image != null && image.length > 0)
				LuaUtils.loadFrames(spr, image, spriteType);
		});

		Lua_helper.add_callback(lua, "getObjectOrder", function(obj:String) {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			if(leObj != null)
				return MusicBeatState.getState().members.indexOf(leObj);
			return -1;
		});
		Lua_helper.add_callback(lua, "setObjectOrder", function(obj:String, position:Int) {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			if(leObj != null) {
				MusicBeatState.getState().remove(leObj, true);
				MusicBeatState.getState().insert(position, leObj);
			}
		});
		Lua_helper.add_callback(lua, "setObjectCamera", function(obj:String, camera:String = 'game') {
			var split:Array<String> = obj.split('.');
			var object:FlxBasic = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				object = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(object != null) {
				object.cameras = [FlxG.camera];
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "screenCenter", function(obj:String, pos:String = 'xy') {
			var split:Array<String> = obj.split('.');
			var spr:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) {
				switch(pos.trim().toLowerCase()) {
					case 'x': spr.screenCenter(X);
					case 'y': spr.screenCenter(Y);
					default:  spr.screenCenter(XY);
				}
			}
		});
		Lua_helper.add_callback(lua, "setGraphicSize", function(obj:String, x:Float, y:Float = 0, updateHitbox:Bool = true) {
			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				poop = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(poop != null) {
				poop.setGraphicSize(x, y);
				if(updateHitbox) poop.updateHitbox();
			}
		});
		Lua_helper.add_callback(lua, "scaleObject", function(obj:String, x:Float, y:Float, updateHitbox:Bool = true) {
			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				poop = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(poop != null) {
				poop.scale.set(x, y);
				if(updateHitbox) poop.updateHitbox();
			}
		});
		Lua_helper.add_callback(lua, "updateHitbox", function(obj:String) {
			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				poop = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(poop != null) poop.updateHitbox();
		});
		Lua_helper.add_callback(lua, "setScrollFactor", function(obj:String, scrollX:Float, scrollY:Float) {
			var split:Array<String> = obj.split('.');
			var object:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				object = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(object != null)
				object.scrollFactor.set(scrollX, scrollY);
		});

		Lua_helper.add_callback(lua, "addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Float = 24, loop:Bool = true) {
			var obj:FlxSprite = cast LuaUtils.getObjectDirectly(obj);
			if(obj != null && obj.animation != null) {
				obj.animation.addByPrefix(name, prefix, framerate, loop);
				if(obj.animation.curAnim == null) {
					var dyn:Dynamic = cast obj;
					if(dyn.playAnim != null) dyn.playAnim(name, true);
					else dyn.animation.play(name, true);
				}
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "addAnimation", function(obj:String, name:String, frames:Any, framerate:Float = 24, loop:Bool = true) {
			return LuaUtils.addAnimByIndices(obj, name, null, frames, framerate, loop);
		});
		Lua_helper.add_callback(lua, "addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:Any, framerate:Float = 24, loop:Bool = false) {
			return LuaUtils.addAnimByIndices(obj, name, prefix, indices, framerate, loop);
		});
		Lua_helper.add_callback(lua, "playAnim", function(obj:String, name:String, ?forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if(obj.playAnim != null) {
				obj.playAnim(name, forced, reverse, startFrame);
				return true;
			} else {
				if(obj.anim != null) obj.anim.play(name, forced, reverse, startFrame);
				else obj.animation.play(name, forced, reverse, startFrame);
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "addOffset", function(obj:String, anim:String, x:Float, y:Float) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if(obj != null && obj.addOffset != null) {
				obj.addOffset(anim, x, y);
				return true;
			}
			return false;
		});

		Lua_helper.add_callback(lua, "doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return stateTweenFunction(tag, vars, {x: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return stateTweenFunction(tag, vars, {y: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return stateTweenFunction(tag, vars, {angle: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return stateTweenFunction(tag, vars, {alpha: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "cancelTween", function(tag:String) LuaUtils.cancelTween(tag));

		Lua_helper.add_callback(lua, "runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			LuaUtils.cancelTimer(tag);
			var variables = MusicBeatState.getVariables();
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('timer_$tag');
			variables.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if(tmr.finished) variables.remove(tag);
				call('onTimerCompleted', [originalTag, tmr.loops, tmr.loopsLeft]);
			}, loops));
			return tag;
		});
		Lua_helper.add_callback(lua, "cancelTimer", function(tag:String) LuaUtils.cancelTimer(tag));

		Lua_helper.add_callback(lua, "playMusic", function(sound:String, ?volume:Float = 1, ?loop:Bool = false) {
			FlxG.sound.playMusic(Paths.music(sound), volume, loop);
		});
		Lua_helper.add_callback(lua, "playSound", function(sound:String, ?volume:Float = 1, ?tag:String = null, ?loop:Bool = false) {
			if(tag != null && tag.length > 0) {
				var originalTag:String = tag;
				tag = LuaUtils.formatVariable('sound_$tag');
				var variables = MusicBeatState.getVariables();
				var oldSnd:FlxSound = variables.get(tag);
				if(oldSnd != null) {
					oldSnd.stop();
					oldSnd.destroy();
				}
				variables.set(tag, FlxG.sound.play(Paths.sound(sound), volume, loop, null, true, function() {
					if(!loop) variables.remove(tag);
					call('onSoundFinished', [originalTag]);
				}));
				return tag;
			}
			FlxG.sound.play(Paths.sound(sound), volume);
			return null;
		});
		Lua_helper.add_callback(lua, "stopSound", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.stop();
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) {
					snd.stop();
					MusicBeatState.getVariables().remove(tag);
				}
			}
		});
		Lua_helper.add_callback(lua, "pauseSound", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.pause();
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.pause();
			}
		});
		Lua_helper.add_callback(lua, "resumeSound", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.play();
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.play();
			}
		});

		Lua_helper.add_callback(lua, "FlxColor", function(color:String) return FlxColor.fromString(color));
		Lua_helper.add_callback(lua, "getColorFromString", function(color:String) return FlxColor.fromString(color));
		Lua_helper.add_callback(lua, "getColorFromHex", function(color:String) return FlxColor.fromString('#$color'));

		Lua_helper.add_callback(lua, "precacheImage", function(name:String, ?allowGPU:Bool = true) {
			Paths.image(name, allowGPU);
		});
		Lua_helper.add_callback(lua, "precacheSound", function(name:String) {
			Paths.sound(name);
		});
		Lua_helper.add_callback(lua, "precacheMusic", function(name:String) {
			Paths.music(name);
		});

		Lua_helper.add_callback(lua, "getBuildTarget", function() return LuaUtils.getBuildTarget());
		Lua_helper.add_callback(lua, "debugPrint", function(text:Dynamic = '', color:String = 'WHITE') {
			trace('[LuaState:$stateName] $text');
		});
		Lua_helper.add_callback(lua, "getMouseX", function() return FlxG.mouse.x);
		Lua_helper.add_callback(lua, "getMouseY", function() return FlxG.mouse.y);
		Lua_helper.add_callback(lua, "mouseClicked", function(?button:String = 'left') {
			switch(button.trim().toLowerCase()) {
				case 'middle': return FlxG.mouse.justPressedMiddle;
				case 'right':  return FlxG.mouse.justPressedRight;
			}
			return FlxG.mouse.justPressed;
		});
		Lua_helper.add_callback(lua, "mousePressed", function(?button:String = 'left') {
			switch(button.trim().toLowerCase()) {
				case 'middle': return FlxG.mouse.pressedMiddle;
				case 'right':  return FlxG.mouse.pressedRight;
			}
			return FlxG.mouse.pressed;
		});
		Lua_helper.add_callback(lua, "mouseReleased", function(?button:String = 'left') {
			switch(button.trim().toLowerCase()) {
				case 'middle': return FlxG.mouse.justReleasedMiddle;
				case 'right':  return FlxG.mouse.justReleasedRight;
			}
			return FlxG.mouse.justReleased;
		});

		#if MODS_ALLOWED
		Lua_helper.add_callback(lua, "getModSetting", function(saveTag:String, ?modName:String = null) {
			if(modName == null) modName = modDirectory;
			if(modName == null) return null;
			return LuaUtils.getModSetting(saveTag, modName);
		});
		#end

		Lua_helper.add_callback(lua, "keyboardJustPressed", function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		Lua_helper.add_callback(lua, "keyboardPressed", function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		Lua_helper.add_callback(lua, "keyboardReleased", function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		Lua_helper.add_callback(lua, "anyGamepadJustPressed", function(name:String) return FlxG.gamepads.anyJustPressed(name));
		Lua_helper.add_callback(lua, "anyGamepadPressed", function(name:String) FlxG.gamepads.anyPressed(name));
		Lua_helper.add_callback(lua, "anyGamepadReleased", function(name:String) return FlxG.gamepads.anyJustReleased(name));
		Lua_helper.add_callback(lua, "gamepadAnalogX", function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return 0.0;
			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		Lua_helper.add_callback(lua, "gamepadAnalogY", function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return 0.0;
			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		Lua_helper.add_callback(lua, "gamepadJustPressed", function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return false;
			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		Lua_helper.add_callback(lua, "gamepadPressed", function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return false;
			return Reflect.getProperty(controller.pressed, name) == true;
		});
		Lua_helper.add_callback(lua, "gamepadReleased", function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return false;
			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		Lua_helper.add_callback(lua, "keyJustPressed", function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_P;
				case 'down': return Controls.instance.NOTE_DOWN_P;
				case 'up': return Controls.instance.NOTE_UP_P;
				case 'right': return Controls.instance.NOTE_RIGHT_P;
				default: return Controls.instance.justPressed(name);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "keyPressed", function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT;
				case 'down': return Controls.instance.NOTE_DOWN;
				case 'up': return Controls.instance.NOTE_UP;
				case 'right': return Controls.instance.NOTE_RIGHT;
				default: return Controls.instance.pressed(name);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "keyReleased", function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_R;
				case 'down': return Controls.instance.NOTE_DOWN_R;
				case 'up': return Controls.instance.NOTE_UP_R;
				case 'right': return Controls.instance.NOTE_RIGHT_R;
				default: return Controls.instance.justReleased(name);
			}
			return false;
		});

		Lua_helper.add_callback(lua, "getPropertyFromClass", function(className:String, variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:Dynamic = Type.resolveClass(className);
			if(obj != null) {
				for(i in 0...split.length)
					obj = LuaUtils.getVarInArray(obj, split[i]);
			}
			return obj;
		});
		Lua_helper.add_callback(lua, "setPropertyFromClass", function(className:String, variable:String, value:Dynamic) {
			var split:Array<String> = variable.split('.');
			var obj:Dynamic = Type.resolveClass(className);
			if(obj != null) {
				if(split.length > 1) {
					var lastObj:Dynamic = obj;
					for(i in 0...split.length - 1)
						lastObj = LuaUtils.getVarInArray(lastObj, split[i]);
					LuaUtils.setVarInArray(lastObj, split[split.length - 1], value);
				} else {
					LuaUtils.setVarInArray(obj, variable, value);
				}
			}
			return value;
		});
		Lua_helper.add_callback(lua, "callMethod", function(obj:Dynamic, funcToRun:String, ?args:Array<Dynamic> = null) {
			if(args == null) args = [];
			var object:Dynamic = obj == null ? MusicBeatState.getState() : LuaUtils.getObjectDirectly(obj);
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
		Lua_helper.add_callback(lua, "instanceArg", function(obj:String) {
			return LuaUtils.getObjectDirectly(obj);
		});

		Lua_helper.add_callback(lua, "makeLuaText", function(tag:String, text:String, width:Int, x:Float, y:Float) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leText:flixel.text.FlxText = new flixel.text.FlxText(x, y, width, text, 16);
			leText.fieldWidth = width;
			MusicBeatState.getVariables().set(tag, leText);
		});
		Lua_helper.add_callback(lua, "setTextString", function(tag:String, text:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.text = text;
		});
		Lua_helper.add_callback(lua, "getTextString", function(tag:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) return obj.text;
			return null;
		});
		Lua_helper.add_callback(lua, "setTextSize", function(tag:String, size:Int) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.size = size;
		});
		Lua_helper.add_callback(lua, "getTextSize", function(tag:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) return obj.size;
			return 0;
		});
		Lua_helper.add_callback(lua, "setTextWidth", function(tag:String, width:Float) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.fieldWidth = width;
		});
		Lua_helper.add_callback(lua, "setTextBorder", function(tag:String, size:Float, color:String, ?style:String = 'outline') {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) {
				var borderStyle:flixel.text.FlxText.FlxTextBorderStyle = OUTLINE;
				switch(style.toLowerCase().trim()) {
					case 'shadow': borderStyle = SHADOW;
					case 'outline_fast': borderStyle = OUTLINE_FAST;
					case 'none': borderStyle = NONE;
				}
				obj.setBorderStyle(borderStyle, CoolUtil.colorFromString(color), size);
			}
		});
		Lua_helper.add_callback(lua, "setTextColor", function(tag:String, color:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.color = CoolUtil.colorFromString(color);
		});
		Lua_helper.add_callback(lua, "setTextFont", function(tag:String, font:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.font = Paths.font(font);
		});
		Lua_helper.add_callback(lua, "setTextItalic", function(tag:String, italic:Bool) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.italic = italic;
		});
		Lua_helper.add_callback(lua, "setTextAlignment", function(tag:String, alignment:String = 'left') {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) {
				obj.alignment = switch(alignment.toLowerCase().trim()) {
					case 'center': CENTER;
					case 'right': RIGHT;
					case 'justify': JUSTIFY;
					default: LEFT;
				};
			}
		});
		Lua_helper.add_callback(lua, "luaTextExists", function(tag:String) {
			var obj = MusicBeatState.getVariables().get(tag);
			return (obj != null && Std.isOfType(obj, flixel.text.FlxText));
		});

		Lua_helper.add_callback(lua, "addLuaText", function(tag:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) add(obj);
		});
		Lua_helper.add_callback(lua, "removeLuaText", function(tag:String, destroy:Bool = true) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj == null) return;
			remove(obj, true);
			if(destroy) {
				MusicBeatState.getVariables().remove(tag);
				obj.destroy();
			}
		});

		Lua_helper.add_callback(lua, "getPixelColor", function(obj:String, x:Int, y:Int) {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) return spr.pixels.getPixel32(x, y);
			return FlxColor.BLACK;
		});
		Lua_helper.add_callback(lua, "getMidpointX", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getMidpoint().x;
			return 0;
		});
		Lua_helper.add_callback(lua, "getMidpointY", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getMidpoint().y;
			return 0;
		});
		Lua_helper.add_callback(lua, "getScreenPositionX", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getScreenPosition(FlxG.camera).x;
			return 0;
		});
		Lua_helper.add_callback(lua, "getScreenPositionY", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getScreenPosition(FlxG.camera).y;
			return 0;
		});
		Lua_helper.add_callback(lua, "objectsOverlap", function(obj1:String, obj2:String) {
			var o1:FlxBasic = LuaUtils.getObjectDirectly(obj1);
			var o2:FlxBasic = LuaUtils.getObjectDirectly(obj2);
			return (o1 != null && o2 != null && FlxG.overlap(o1, o2));
		});
		Lua_helper.add_callback(lua, "setBlendMode", function(obj:String, blend:String = '') {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) {
				spr.blend = LuaUtils.blendModeFromString(blend);
				return true;
			}
			return false;
		});

		Lua_helper.add_callback(lua, "startTween", function(tag:String, vars:String, values:Any = null, duration:Float, ?options:Any = null) {
			var target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if(target != null) {
				if(values != null) {
					var myOptions:LuaTweenOptions = LuaUtils.getLuaTween(options);
					if(tag != null) {
						var variables = MusicBeatState.getVariables();
						var originalTag:String = 'tween_' + LuaUtils.formatVariable(tag);
						variables.set(tag, FlxTween.tween(target, values, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
							onUpdate: function(twn:FlxTween) {
								if(myOptions.onUpdate != null) call(myOptions.onUpdate, [originalTag, vars]);
							},
							onStart: function(twn:FlxTween) {
								if(myOptions.onStart != null) call(myOptions.onStart, [originalTag, vars]);
							},
							onComplete: function(twn:FlxTween) {
								if(twn.type == FlxTween.ONESHOT || twn.type == FlxTween.BACKWARD) variables.remove(tag);
								if(myOptions.onComplete != null) call(myOptions.onComplete, [originalTag, vars]);
							}
						} : null));
						return tag;
					} else {
						FlxTween.tween(target, values, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
							onUpdate: function(twn:FlxTween) {
								if(myOptions.onUpdate != null) call(myOptions.onUpdate, [null, vars]);
							},
							onStart: function(twn:FlxTween) {
								if(myOptions.onStart != null) call(myOptions.onStart, [null, vars]);
							},
							onComplete: function(twn:FlxTween) {
								if(myOptions.onComplete != null) call(myOptions.onComplete, [null, vars]);
							}
						} : null);
					}
				}
			}
			return null;
		});
		Lua_helper.add_callback(lua, "doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ?ease:String = 'linear') {
			var target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if(target != null) {
				var curColor:FlxColor = target.color;
				curColor.alphaFloat = target.alpha;
				if(tag != null) {
					var originalTag:String = tag;
					tag = LuaUtils.formatVariable('tween_$tag');
					var variables = MusicBeatState.getVariables();
					variables.set(tag, FlxTween.color(target, duration, curColor, CoolUtil.colorFromString(targetColor), {
						ease: LuaUtils.getTweenEaseByString(ease),
						onComplete: function(twn:FlxTween) {
							variables.remove(tag);
							call('onTweenCompleted', [originalTag, vars]);
						}
					}));
					return tag;
				} else {
					FlxTween.color(target, duration, curColor, CoolUtil.colorFromString(targetColor), {ease: LuaUtils.getTweenEaseByString(ease)});
				}
			}
			return null;
		});

		Lua_helper.add_callback(lua, "cameraShake", function(camera:String, intensity:Float, duration:Float) {
			FlxG.camera.shake(intensity, duration);
		});
		Lua_helper.add_callback(lua, "cameraFlash", function(camera:String, color:String, duration:Float, forced:Bool) {
			FlxG.camera.flash(CoolUtil.colorFromString(color), duration, null, forced);
		});
		Lua_helper.add_callback(lua, "cameraFade", function(camera:String, color:String, duration:Float, forced:Bool, ?fadeOut:Bool = false) {
			FlxG.camera.fade(CoolUtil.colorFromString(color), duration, fadeOut, null, forced);
		});
		Lua_helper.add_callback(lua, "setCameraScroll", function(x:Float, y:Float) FlxG.camera.scroll.set(x - FlxG.width / 2, y - FlxG.height / 2));
		Lua_helper.add_callback(lua, "addCameraScroll", function(?x:Float = 0, ?y:Float = 0) FlxG.camera.scroll.add(x, y));
		Lua_helper.add_callback(lua, "getCameraScrollX", function() return FlxG.camera.scroll.x + FlxG.width / 2);
		Lua_helper.add_callback(lua, "getCameraScrollY", function() return FlxG.camera.scroll.y + FlxG.height / 2);
		Lua_helper.add_callback(lua, "setCameraScrollX", function(x:Float) FlxG.camera.scroll.x = x);
		Lua_helper.add_callback(lua, "setCameraScrollY", function(y:Float) FlxG.camera.scroll.y = y);
		Lua_helper.add_callback(lua, "getCameraScrollRawX", function() return FlxG.camera.scroll.x);
		Lua_helper.add_callback(lua, "getCameraScrollRawY", function() return FlxG.camera.scroll.y);
		Lua_helper.add_callback(lua, "lerp", function(a:Float, b:Float, t:Float) return a + (b - a) * t);
		Lua_helper.add_callback(lua, "setCameraZoom", function(zoom:Float) FlxG.camera.zoom = zoom);
		Lua_helper.add_callback(lua, "getCameraZoom", function() return FlxG.camera.zoom);
		Lua_helper.add_callback(lua, "setMouseVisible", function(visible:Bool) FlxG.mouse.visible = visible);
		Lua_helper.add_callback(lua, "getMouseVisible", function() return FlxG.mouse.visible);

		Lua_helper.add_callback(lua, "addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			#if HSCRIPT_ALLOWED
			var str:String = '';
			if(libPackage.length > 0) str = libPackage + '.';
			var c:Dynamic = Type.resolveClass(str + libName);
			if(c == null) c = Type.resolveEnum(str + libName);
			if(hscript == null) initHaxeModuleCode('', null);
			if(hscript != null && c != null) hscript.set(libName, c);
			#end
		});

		Lua_helper.add_callback(lua, "getSave", function(key:String) {
			if(FlxG.save.data != null) return Reflect.getProperty(FlxG.save.data, key);
			return null;
		});
		Lua_helper.add_callback(lua, "setSave", function(key:String, value:Dynamic) {
			if(FlxG.save.data != null) Reflect.setProperty(FlxG.save.data, key, value);
		});
		Lua_helper.add_callback(lua, "flushSave", function() FlxG.save.flush());

		#if HSCRIPT_ALLOWED
		Lua_helper.add_callback(lua, "runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			initHaxeModuleCode(codeToRun, varsToBring);
			if(hscript != null)
			{
				var retVal = hscript.call(funcToRun, funcArgs);
				if(retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
				else if(hscript.returnValue != null)
				{
					return hscript.returnValue;
				}
			}
			return null;
		});
		Lua_helper.add_callback(lua, "runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null):Dynamic {
			if(hscript != null)
			{
				var retVal = hscript.call(funcToRun, funcArgs);
				if(retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
			}
			else
			{
				var pos:HScriptInfos = cast {fileName: stateName, showLine: false, isLua: true};
				if(lastCalledFunction != '') pos.funcName = lastCalledFunction;
				Iris.error("runHaxeFunction: HScript has not been initialized yet! Use \"runHaxeCode\" to initialize it", pos);
			}
			return null;
		});
		Lua_helper.add_callback(lua, "addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			var str:String = '';
			if(libPackage.length > 0)
				str = libPackage + '.';
			else if(libName == null)
				libName = '';

			var c:Dynamic = Type.resolveClass(str + libName);
			if(c == null)
				c = Type.resolveEnum(str + libName);

			if(hscript == null)
				initHaxeModuleCode('', null);

			if(hscript != null)
			{
				var pos:HScriptInfos = cast {fileName: stateName, showLine: false, isLua: true};
				if(lastCalledFunction != '') pos.funcName = lastCalledFunction;

				try {
					if(c != null) hscript.set(libName, c);
				}
				catch(e:IrisError) {
					Iris.error(Printer.errorToString(e, false), pos);
				}
			}
		});
		#end
	}

	override function create()
	{
		if(modDirectory != null && modDirectory != '')
			Mods.currentModDirectory = modDirectory;

		persistentUpdate = true;
		super.create();

		call('onCreate', []);

		if(oldStickers != null && oldStickers.length > 0) {
			this.persistentUpdate = false;
			this.persistentDraw = true;
			openSubState(new substates.StickerSubState(oldStickers, null));
		}
	}

	override function closeSubState()
	{
		persistentUpdate = true;
		super.closeSubState();
		call('onCloseSubState', []);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(stateName == 'MainMenuState' && FlxG.keys.justPressed.TAB) {
			FlxG.mouse.visible = false;
			persistentUpdate = false;
			openSubState(new backend.ModSelectorSubstate());
		}

		call('onUpdate', [elapsed]);
	}

	override function destroy()
	{
		if(lua != null) {
			call('onDestroy', []);
			Lua.close(lua);
			lua = null;
		}
		#if HSCRIPT_ALLOWED
		if(hscript != null)
		{
			hscript.destroy();
			hscript = null;
		}
		#end
		super.destroy();
	}

	public function call(func:String, args:Array<Dynamic>):Dynamic
	{
		if(closed || lua == null) return LuaUtils.Function_Continue;
		try {
			Lua.getglobal(lua, func);
			var type:Int = Lua.type(lua, -1);
			if(type != Lua.LUA_TFUNCTION) {
				Lua.pop(lua, 1);
				return LuaUtils.Function_Continue;
			}
			for(arg in args) Convert.toLua(lua, arg);
			var status:Int = Lua.pcall(lua, args.length, 1, 0);
			if(status != Lua.LUA_OK) {
				var error:String = Lua.tostring(lua, -1);
				Lua.pop(lua, 1);
				trace('LuaState error in $func: $error');
				return LuaUtils.Function_Continue;
			}
			var result:Dynamic = cast Convert.fromLua(lua, -1);
			if(result == null) result = LuaUtils.Function_Continue;
			Lua.pop(lua, 1);
			return result;
		} catch(e:Dynamic) {
			trace('LuaState exception in $func: $e');
		}
		return LuaUtils.Function_Continue;
	}

	public function set(variable:String, data:Dynamic)
	{
		if(lua == null) return;
		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
	}

    #if HSCRIPT_ALLOWED
	function initHaxeModuleCode(code:String, ?varsToBring:Any = null)
	{
		if(hscript != null)
		{
			hscript.destroy();
			hscript = null;
		}
		try {
			hscript = new HScript(null, code, varsToBring);
			hscript.origin = stateName;
			hscript.modFolder = modDirectory;
		}
		catch(e:IrisError) {
			var pos:HScriptInfos = cast {fileName: stateName, isLua: true};
			if(lastCalledFunction != '') pos.funcName = lastCalledFunction;
			Iris.error(Printer.errorToString(e, false), pos);
			hscript = null;
		}
	}
	#end

	function stateTweenFunction(tag:String, vars:String, tweenValue:Any, duration:Float, ease:String):Dynamic
	{
		var target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
		var variables = MusicBeatState.getVariables();
		if(target != null) {
			if(tag != null) {
				var originalTag:String = tag;
				tag = LuaUtils.formatVariable('tween_$tag');
				variables.set(tag, FlxTween.tween(target, tweenValue, duration, {
					ease: LuaUtils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						variables.remove(tag);
						call('onTweenCompleted', [originalTag, vars]);
					}
				}));
				return tag;
			} else {
				FlxTween.tween(target, tweenValue, duration, {ease: LuaUtils.getTweenEaseByString(ease)});
			}
		}
		return null;
	}
}

class LuaStateLoader
{
	public static function loadStateScript(stateName:String, ?stickers:Array<substates.StickerSubState.StickerSprite>):FlxState
	{
		#if MODS_ALLOWED
		var save = FlxG.save;
		var modMode:String = null;
		if(save != null && save.data != null && save.data.modMode != null)
			modMode = save.data.modMode;

		if(modMode == 'DISABLE MODS')
			return null;

		var savedModDirectory = Mods.currentModDirectory;

		if(savedModDirectory == null || savedModDirectory == '') {
			if(save != null && save.data != null && save.data.currentMod != null && save.data.currentMod != '') {
				savedModDirectory = save.data.currentMod;
				Mods.currentModDirectory = savedModDirectory;
			}
		}

		if(savedModDirectory != null && savedModDirectory != '') {
			var statesDir = Paths.modFolders('$savedModDirectory/states/');
			var scriptPath = findScriptInDir(statesDir, '$stateName.lua');
			var exists = scriptPath != null;

			if(exists && stateName != 'LoadingState' && stateName != 'LoadingScreen') {
				Mods.currentModDirectory = savedModDirectory;
				Mods.loadTopMod();

				try {
					var stateInstance = new LuaState(scriptPath, stateName, savedModDirectory, stickers);
					return stateInstance;
				} catch(e:Dynamic) {
					trace('LuaStateLoader: Error creating state $stateName: $e');
				}
			}
		}
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

	public static function createLoadingScript(barBack:flixel.FlxSprite, bar:flixel.FlxSprite, loadingState:states.LoadingState):LoadingLuaScript
	{
		#if MODS_ALLOWED
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.trim().length > 0)
		{
			var scriptPath:String = 'mods/${Mods.currentModDirectory}/data/LoadingScreen.lua';
			if(!sys.FileSystem.exists(scriptPath))
				scriptPath = 'mods/${Mods.currentModDirectory}/data/LoadingState.lua';
			if(sys.FileSystem.exists(scriptPath))
			{
				try
				{
					return new LoadingLuaScript(scriptPath, barBack, bar, loadingState);
				}
				catch(e:Dynamic)
				{
					trace('LuaStateLoader: Error creating LoadingLuaScript: $e');
				}
			}
		}
		#end
		return null;
	}
}

class LoadingLuaScript
{
	public var lua:State = null;
	public var scriptName:String;
	public var closed:Bool = false;
	public var lastCalledFunction:String = '';

	var loadingState:states.LoadingState;

	#if HSCRIPT_ALLOWED
	public var hscript:HScript = null;
	var modDirectory:String = null;
	#end

	public function new(scriptPath:String, barBack:flixel.FlxSprite, bar:flixel.FlxSprite, loadingState:states.LoadingState)
	{
		this.scriptName = scriptPath;
		this.loadingState = loadingState;

		lua = LuaL.newstate();
		LuaL.openlibs(lua);

		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('Function_StopLua', LuaUtils.Function_StopLua);
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);
		set('buildTarget', LuaUtils.getBuildTarget());
		set('currentModDirectory', Mods.currentModDirectory);

		MusicBeatState.getVariables().set('barBack', barBack);
		MusicBeatState.getVariables().set('bar', bar);
		set('game', loadingState);

		registerCallbacks();

		try
		{
			var result:Dynamic = LuaL.dofile(lua, scriptPath);
			var resultStr:String = Lua.tostring(lua, result);
			if(resultStr != null && result != 0)
			{
				trace('LoadingLuaScript: Error loading $scriptPath\n$resultStr');
				lua = null;
				return;
			}
		}
		catch(e:Dynamic)
		{
			trace('LoadingLuaScript: Exception loading $scriptPath: $e');
			lua = null;
			return;
		}
	}

	function registerCallbacks()
	{
		Lua_helper.add_callback(lua, "getLoaded", function() return states.LoadingState.loaded);
		Lua_helper.add_callback(lua, "getLoadMax", function() return states.LoadingState.loadMax);
		Lua_helper.add_callback(lua, "addBehindBar", function(tag:String) {
			var obj:flixel.FlxBasic = MusicBeatState.getVariables().get(tag);
			if(obj != null) loadingState.addBehindBar(obj);
		});

		Lua_helper.add_callback(lua, "switchState", function(stateName:String) {
			backend.StateManager.switchState(stateName);
		});
		Lua_helper.add_callback(lua, "isMusicPlaying", function() {
			return FlxG.sound.music != null && FlxG.sound.music.playing;
		});
		Lua_helper.add_callback(lua, "getScore", function(songName:String, diffIndex:Int) {
			return backend.Highscore.getScore(songName, diffIndex);
		});
		Lua_helper.add_callback(lua, "getDifficulties", function() {
			return backend.Difficulty.list;
		});
		Lua_helper.add_callback(lua, "getDifficultyName", function(index:Int) {
			if(index < 0 || index >= backend.Difficulty.list.length) return 'normal';
			return backend.Difficulty.list[index];
		});
		Lua_helper.add_callback(lua, "lerp", function(a:Float, b:Float, t:Float) return a + (b - a) * t);
		Lua_helper.add_callback(lua, "flxLerp", function(a:Float, b:Float, t:Float) return flixel.math.FlxMath.lerp(a, b, t));
		Lua_helper.add_callback(lua, "setCameraZoom", function(zoom:Float) FlxG.camera.zoom = zoom);
		Lua_helper.add_callback(lua, "getCameraZoom", function() return FlxG.camera.zoom);
		Lua_helper.add_callback(lua, "setCameraScrollX", function(x:Float) FlxG.camera.scroll.x = x);
		Lua_helper.add_callback(lua, "setCameraScrollY", function(y:Float) FlxG.camera.scroll.y = y);
		Lua_helper.add_callback(lua, "setMouseVisible", function(visible:Bool) FlxG.mouse.visible = visible);
		Lua_helper.add_callback(lua, "getMouseVisible", function() return FlxG.mouse.visible);
		Lua_helper.add_callback(lua, "resetState", function() {
			MusicBeatState.resetState();
		});
		Lua_helper.add_callback(lua, "openSubState", function(substate:Dynamic) {
			if(Std.isOfType(substate, String)) {
				var shortNames:Map<String, String> = [
					'EditorPickerSubstate' => 'states.editors.EditorPickerSubstate'
				];
				var resolved:String = shortNames.exists(substate) ? shortNames.get(substate) : substate;
				var cls = Type.resolveClass(resolved);
				if(cls != null) loadingState.openSubState(Type.createInstance(cls, []));
			} else {
				loadingState.openSubState(substate);
			}
		});
		Lua_helper.add_callback(lua, "closeSubState", function() {
			loadingState.closeSubState();
		});
		Lua_helper.add_callback(lua, "setVar", function(varName:String, value:Dynamic) {
			MusicBeatState.getVariables().set(varName, value);
			return value;
		});
		Lua_helper.add_callback(lua, "getVar", function(varName:String) {
			return MusicBeatState.getVariables().get(varName);
		});
		Lua_helper.add_callback(lua, "setProperty", function(variable:String, value:Dynamic) {
			var split:Array<String> = variable.split('.');
			if(split.length > 1)
				LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1], value);
			else
				LuaUtils.setVarInArray(MusicBeatState.getState(), variable, value);
			return value;
		});
		Lua_helper.add_callback(lua, "getProperty", function(variable:String) {
			var split:Array<String> = variable.split('.');
			if(split.length > 1)
				return LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			return LuaUtils.getVarInArray(MusicBeatState.getState(), variable);
		});
		Lua_helper.add_callback(lua, "makeLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
				leSprite.loadGraphic(Paths.image(image));
			MusicBeatState.getVariables().set(tag, leSprite);
			leSprite.active = true;
		});
		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = 'auto') {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
				LuaUtils.loadFrames(leSprite, image, spriteType);
			MusicBeatState.getVariables().set(tag, leSprite);
		});
		Lua_helper.add_callback(lua, "addLuaSprite", function(tag:String, ?inFront:Bool = true) {
			var mySprite:FlxSprite = MusicBeatState.getVariables().get(tag);
			if(mySprite == null) return;
			loadingState.add(mySprite);
		});
		Lua_helper.add_callback(lua, "removeLuaSprite", function(tag:String, destroy:Bool = true) {
			var obj:FlxSprite = LuaUtils.getObjectDirectly(tag);
			if(obj == null || obj.destroy == null) return;
			loadingState.remove(obj, true);
			if(destroy) {
				MusicBeatState.getVariables().remove(tag);
				obj.destroy();
			}
		});
		Lua_helper.add_callback(lua, "luaSpriteExists", function(tag:String) {
			var obj = MusicBeatState.getVariables().get(tag);
			return (obj != null && Std.isOfType(obj, ModchartSprite));
		});
		Lua_helper.add_callback(lua, "makeGraphic", function(obj:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF') {
			var spr:FlxSprite = LuaUtils.getObjectDirectly(obj);
			if(spr != null) spr.makeGraphic(width, height, CoolUtil.colorFromString(color));
		});
		Lua_helper.add_callback(lua, "loadGraphic", function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			var animated = gridX != 0 || gridY != 0;
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && image != null && image.length > 0)
				spr.loadGraphic(Paths.image(image), animated, gridX, gridY);
		});
		Lua_helper.add_callback(lua, "loadFrames", function(variable:String, image:String, spriteType:String = 'auto') {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && image != null && image.length > 0)
				LuaUtils.loadFrames(spr, image, spriteType);
		});
		Lua_helper.add_callback(lua, "getObjectOrder", function(obj:String) {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			if(leObj != null)
				return MusicBeatState.getState().members.indexOf(leObj);
			return -1;
		});
		Lua_helper.add_callback(lua, "setObjectOrder", function(obj:String, position:Int) {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			if(leObj != null) {
				MusicBeatState.getState().remove(leObj, true);
				MusicBeatState.getState().insert(position, leObj);
			}
		});
		Lua_helper.add_callback(lua, "setObjectCamera", function(obj:String, camera:String = 'game') {
			var split:Array<String> = obj.split('.');
			var object:FlxBasic = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				object = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(object != null) {
				object.cameras = [FlxG.camera];
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "screenCenter", function(obj:String, pos:String = 'xy') {
			var split:Array<String> = obj.split('.');
			var spr:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) {
				switch(pos.trim().toLowerCase()) {
					case 'x': spr.screenCenter(X);
					case 'y': spr.screenCenter(Y);
					default:  spr.screenCenter(XY);
				}
			}
		});
		Lua_helper.add_callback(lua, "setGraphicSize", function(obj:String, x:Float, y:Float = 0, updateHitbox:Bool = true) {
			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				poop = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(poop != null) {
				poop.setGraphicSize(x, y);
				if(updateHitbox) poop.updateHitbox();
			}
		});
		Lua_helper.add_callback(lua, "scaleObject", function(obj:String, x:Float, y:Float, updateHitbox:Bool = true) {
			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				poop = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(poop != null) {
				poop.scale.set(x, y);
				if(updateHitbox) poop.updateHitbox();
			}
		});
		Lua_helper.add_callback(lua, "updateHitbox", function(obj:String) {
			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				poop = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(poop != null) poop.updateHitbox();
		});
		Lua_helper.add_callback(lua, "setScrollFactor", function(obj:String, scrollX:Float, scrollY:Float) {
			var split:Array<String> = obj.split('.');
			var object:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				object = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(object != null)
				object.scrollFactor.set(scrollX, scrollY);
		});
		Lua_helper.add_callback(lua, "addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Float = 24, loop:Bool = true) {
			var obj:FlxSprite = cast LuaUtils.getObjectDirectly(obj);
			if(obj != null && obj.animation != null) {
				obj.animation.addByPrefix(name, prefix, framerate, loop);
				if(obj.animation.curAnim == null) {
					var dyn:Dynamic = cast obj;
					if(dyn.playAnim != null) dyn.playAnim(name, true);
					else dyn.animation.play(name, true);
				}
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "addAnimation", function(obj:String, name:String, frames:Any, framerate:Float = 24, loop:Bool = true) {
			return LuaUtils.addAnimByIndices(obj, name, null, frames, framerate, loop);
		});
		Lua_helper.add_callback(lua, "addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:Any, framerate:Float = 24, loop:Bool = false) {
			return LuaUtils.addAnimByIndices(obj, name, prefix, indices, framerate, loop);
		});
		Lua_helper.add_callback(lua, "playAnim", function(obj:String, name:String, ?forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if(obj.playAnim != null) {
				obj.playAnim(name, forced, reverse, startFrame);
				return true;
			} else {
				if(obj.anim != null) obj.anim.play(name, forced, reverse, startFrame);
				else obj.animation.play(name, forced, reverse, startFrame);
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "addOffset", function(obj:String, anim:String, x:Float, y:Float) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if(obj != null && obj.addOffset != null) {
				obj.addOffset(anim, x, y);
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return stateTweenFunction(tag, vars, {x: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return stateTweenFunction(tag, vars, {y: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return stateTweenFunction(tag, vars, {angle: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return stateTweenFunction(tag, vars, {alpha: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "cancelTween", function(tag:String) LuaUtils.cancelTween(tag));
		Lua_helper.add_callback(lua, "runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			LuaUtils.cancelTimer(tag);
			var variables = MusicBeatState.getVariables();
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('timer_$tag');
			variables.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if(tmr.finished) variables.remove(tag);
				call('onTimerCompleted', [originalTag, tmr.loops, tmr.loopsLeft]);
			}, loops));
			return tag;
		});
		Lua_helper.add_callback(lua, "cancelTimer", function(tag:String) LuaUtils.cancelTimer(tag));
		Lua_helper.add_callback(lua, "playMusic", function(sound:String, ?volume:Float = 1, ?loop:Bool = false) {
			FlxG.sound.playMusic(Paths.music(sound), volume, loop);
		});
		Lua_helper.add_callback(lua, "playSound", function(sound:String, ?volume:Float = 1, ?tag:String = null, ?loop:Bool = false) {
			if(tag != null && tag.length > 0) {
				var originalTag:String = tag;
				tag = LuaUtils.formatVariable('sound_$tag');
				var variables = MusicBeatState.getVariables();
				var oldSnd:FlxSound = variables.get(tag);
				if(oldSnd != null) {
					oldSnd.stop();
					oldSnd.destroy();
				}
				variables.set(tag, FlxG.sound.play(Paths.sound(sound), volume, loop, null, true, function() {
					if(!loop) variables.remove(tag);
					call('onSoundFinished', [originalTag]);
				}));
				return tag;
			}
			FlxG.sound.play(Paths.sound(sound), volume);
			return null;
		});
		Lua_helper.add_callback(lua, "stopSound", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.stop();
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) {
					snd.stop();
					MusicBeatState.getVariables().remove(tag);
				}
			}
		});
		Lua_helper.add_callback(lua, "pauseSound", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.pause();
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.pause();
			}
		});
		Lua_helper.add_callback(lua, "resumeSound", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.play();
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.play();
			}
		});
		Lua_helper.add_callback(lua, "FlxColor", function(color:String) return FlxColor.fromString(color));
		Lua_helper.add_callback(lua, "getColorFromString", function(color:String) return FlxColor.fromString(color));
		Lua_helper.add_callback(lua, "getColorFromHex", function(color:String) return FlxColor.fromString('#$color'));
		Lua_helper.add_callback(lua, "precacheImage", function(name:String, ?allowGPU:Bool = true) {
			Paths.image(name, allowGPU);
		});
		Lua_helper.add_callback(lua, "precacheSound", function(name:String) {
			Paths.sound(name);
		});
		Lua_helper.add_callback(lua, "precacheMusic", function(name:String) {
			Paths.music(name);
		});
		Lua_helper.add_callback(lua, "getBuildTarget", function() return LuaUtils.getBuildTarget());
		Lua_helper.add_callback(lua, "debugPrint", function(text:Dynamic = '', color:String = 'WHITE') {
			trace('[LoadingScript:$scriptName] $text');
		});
		Lua_helper.add_callback(lua, "getMouseX", function() return FlxG.mouse.x);
		Lua_helper.add_callback(lua, "getMouseY", function() return FlxG.mouse.y);
		Lua_helper.add_callback(lua, "mouseClicked", function(?button:String = 'left') {
			switch(button.trim().toLowerCase()) {
				case 'middle': return FlxG.mouse.justPressedMiddle;
				case 'right':  return FlxG.mouse.justPressedRight;
			}
			return FlxG.mouse.justPressed;
		});
		Lua_helper.add_callback(lua, "mousePressed", function(?button:String = 'left') {
			switch(button.trim().toLowerCase()) {
				case 'middle': return FlxG.mouse.pressedMiddle;
				case 'right':  return FlxG.mouse.pressedRight;
			}
			return FlxG.mouse.pressed;
		});
		Lua_helper.add_callback(lua, "mouseReleased", function(?button:String = 'left') {
			switch(button.trim().toLowerCase()) {
				case 'middle': return FlxG.mouse.justReleasedMiddle;
				case 'right':  return FlxG.mouse.justReleasedRight;
			}
			return FlxG.mouse.justReleased;
		});
		#if MODS_ALLOWED
		Lua_helper.add_callback(lua, "getModSetting", function(saveTag:String, ?modName:String = null) {
			if(modName == null) modName = Mods.currentModDirectory;
			if(modName == null) return null;
			return LuaUtils.getModSetting(saveTag, modName);
		});
		#end
		Lua_helper.add_callback(lua, "keyboardJustPressed", function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		Lua_helper.add_callback(lua, "keyboardPressed", function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		Lua_helper.add_callback(lua, "keyboardReleased", function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));
		Lua_helper.add_callback(lua, "anyGamepadJustPressed", function(name:String) return FlxG.gamepads.anyJustPressed(name));
		Lua_helper.add_callback(lua, "anyGamepadPressed", function(name:String) FlxG.gamepads.anyPressed(name));
		Lua_helper.add_callback(lua, "anyGamepadReleased", function(name:String) return FlxG.gamepads.anyJustReleased(name));
		Lua_helper.add_callback(lua, "gamepadAnalogX", function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return 0.0;
			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		Lua_helper.add_callback(lua, "gamepadAnalogY", function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return 0.0;
			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		Lua_helper.add_callback(lua, "gamepadJustPressed", function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return false;
			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		Lua_helper.add_callback(lua, "gamepadPressed", function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return false;
			return Reflect.getProperty(controller.pressed, name) == true;
		});
		Lua_helper.add_callback(lua, "gamepadReleased", function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if(controller == null) return false;
			return Reflect.getProperty(controller.justReleased, name) == true;
		});
		Lua_helper.add_callback(lua, "keyJustPressed", function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_P;
				case 'down': return Controls.instance.NOTE_DOWN_P;
				case 'up': return Controls.instance.NOTE_UP_P;
				case 'right': return Controls.instance.NOTE_RIGHT_P;
				default: return Controls.instance.justPressed(name);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "keyPressed", function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT;
				case 'down': return Controls.instance.NOTE_DOWN;
				case 'up': return Controls.instance.NOTE_UP;
				case 'right': return Controls.instance.NOTE_RIGHT;
				default: return Controls.instance.pressed(name);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "keyReleased", function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_R;
				case 'down': return Controls.instance.NOTE_DOWN_R;
				case 'up': return Controls.instance.NOTE_UP_R;
				case 'right': return Controls.instance.NOTE_RIGHT_R;
				default: return Controls.instance.justReleased(name);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "getPropertyFromClass", function(className:String, variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:Dynamic = Type.resolveClass(className);
			if(obj != null) {
				for(i in 0...split.length)
					obj = LuaUtils.getVarInArray(obj, split[i]);
			}
			return obj;
		});
		Lua_helper.add_callback(lua, "setPropertyFromClass", function(className:String, variable:String, value:Dynamic) {
			var split:Array<String> = variable.split('.');
			var obj:Dynamic = Type.resolveClass(className);
			if(obj != null) {
				if(split.length > 1) {
					var lastObj:Dynamic = obj;
					for(i in 0...split.length - 1)
						lastObj = LuaUtils.getVarInArray(lastObj, split[i]);
					LuaUtils.setVarInArray(lastObj, split[split.length - 1], value);
				} else {
					LuaUtils.setVarInArray(obj, variable, value);
				}
			}
			return value;
		});
		Lua_helper.add_callback(lua, "callMethod", function(obj:Dynamic, funcToRun:String, ?args:Array<Dynamic> = null) {
			if(args == null) args = [];
			var object:Dynamic = obj == null ? MusicBeatState.getState() : LuaUtils.getObjectDirectly(obj);
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
		Lua_helper.add_callback(lua, "instanceArg", function(obj:String) {
			return LuaUtils.getObjectDirectly(obj);
		});
		Lua_helper.add_callback(lua, "makeLuaText", function(tag:String, text:String, width:Int, x:Float, y:Float) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leText:flixel.text.FlxText = new flixel.text.FlxText(x, y, width, text, 16);
			leText.fieldWidth = width;
			MusicBeatState.getVariables().set(tag, leText);
		});
		Lua_helper.add_callback(lua, "setTextString", function(tag:String, text:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.text = text;
		});
		Lua_helper.add_callback(lua, "getTextString", function(tag:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) return obj.text;
			return null;
		});
		Lua_helper.add_callback(lua, "setTextSize", function(tag:String, size:Int) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.size = size;
		});
		Lua_helper.add_callback(lua, "getTextSize", function(tag:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) return obj.size;
			return 0;
		});
		Lua_helper.add_callback(lua, "setTextWidth", function(tag:String, width:Float) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.fieldWidth = width;
		});
		Lua_helper.add_callback(lua, "setTextBorder", function(tag:String, size:Float, color:String, ?style:String = 'outline') {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) {
				var borderStyle:flixel.text.FlxText.FlxTextBorderStyle = OUTLINE;
				switch(style.toLowerCase().trim()) {
					case 'shadow': borderStyle = SHADOW;
					case 'outline_fast': borderStyle = OUTLINE_FAST;
					case 'none': borderStyle = NONE;
				}
				obj.setBorderStyle(borderStyle, CoolUtil.colorFromString(color), size);
			}
		});
		Lua_helper.add_callback(lua, "setTextColor", function(tag:String, color:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.color = CoolUtil.colorFromString(color);
		});
		Lua_helper.add_callback(lua, "setTextFont", function(tag:String, font:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.font = Paths.font(font);
		});
		Lua_helper.add_callback(lua, "setTextItalic", function(tag:String, italic:Bool) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) obj.italic = italic;
		});
		Lua_helper.add_callback(lua, "setTextAlignment", function(tag:String, alignment:String = 'left') {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) {
				obj.alignment = switch(alignment.toLowerCase().trim()) {
					case 'center': CENTER;
					case 'right': RIGHT;
					case 'justify': JUSTIFY;
					default: LEFT;
				};
			}
		});
		Lua_helper.add_callback(lua, "luaTextExists", function(tag:String) {
			var obj = MusicBeatState.getVariables().get(tag);
			return (obj != null && Std.isOfType(obj, flixel.text.FlxText));
		});
		Lua_helper.add_callback(lua, "addLuaText", function(tag:String) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj != null) loadingState.add(obj);
		});
		Lua_helper.add_callback(lua, "removeLuaText", function(tag:String, destroy:Bool = true) {
			var obj:flixel.text.FlxText = MusicBeatState.getVariables().get(tag);
			if(obj == null) return;
			loadingState.remove(obj, true);
			if(destroy) {
				MusicBeatState.getVariables().remove(tag);
				obj.destroy();
			}
		});
		Lua_helper.add_callback(lua, "getPixelColor", function(obj:String, x:Int, y:Int) {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) return spr.pixels.getPixel32(x, y);
			return FlxColor.BLACK;
		});
		Lua_helper.add_callback(lua, "getMidpointX", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getMidpoint().x;
			return 0;
		});
		Lua_helper.add_callback(lua, "getMidpointY", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getMidpoint().y;
			return 0;
		});
		Lua_helper.add_callback(lua, "getScreenPositionX", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getScreenPosition(FlxG.camera).x;
			return 0;
		});
		Lua_helper.add_callback(lua, "getScreenPositionY", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getScreenPosition(FlxG.camera).y;
			return 0;
		});
		Lua_helper.add_callback(lua, "objectsOverlap", function(obj1:String, obj2:String) {
			var o1:FlxBasic = LuaUtils.getObjectDirectly(obj1);
			var o2:FlxBasic = LuaUtils.getObjectDirectly(obj2);
			return (o1 != null && o2 != null && FlxG.overlap(o1, o2));
		});
		Lua_helper.add_callback(lua, "setBlendMode", function(obj:String, blend:String = '') {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null) {
				spr.blend = LuaUtils.blendModeFromString(blend);
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "startTween", function(tag:String, vars:String, values:Any = null, duration:Float, ?options:Any = null) {
			var target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if(target != null) {
				if(values != null) {
					var myOptions:LuaTweenOptions = LuaUtils.getLuaTween(options);
					if(tag != null) {
						var variables = MusicBeatState.getVariables();
						var originalTag:String = 'tween_' + LuaUtils.formatVariable(tag);
						variables.set(tag, FlxTween.tween(target, values, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
							onUpdate: function(twn:FlxTween) {
								if(myOptions.onUpdate != null) call(myOptions.onUpdate, [originalTag, vars]);
							},
							onStart: function(twn:FlxTween) {
								if(myOptions.onStart != null) call(myOptions.onStart, [originalTag, vars]);
							},
							onComplete: function(twn:FlxTween) {
								if(twn.type == FlxTween.ONESHOT || twn.type == FlxTween.BACKWARD) variables.remove(tag);
								if(myOptions.onComplete != null) call(myOptions.onComplete, [originalTag, vars]);
							}
						} : null));
						return tag;
					} else {
						FlxTween.tween(target, values, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
							onUpdate: function(twn:FlxTween) {
								if(myOptions.onUpdate != null) call(myOptions.onUpdate, [null, vars]);
							},
							onStart: function(twn:FlxTween) {
								if(myOptions.onStart != null) call(myOptions.onStart, [null, vars]);
							},
							onComplete: function(twn:FlxTween) {
								if(myOptions.onComplete != null) call(myOptions.onComplete, [null, vars]);
							}
						} : null);
					}
				}
			}
			return null;
		});
		Lua_helper.add_callback(lua, "doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ?ease:String = 'linear') {
			var target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if(target != null) {
				var curColor:FlxColor = target.color;
				curColor.alphaFloat = target.alpha;
				if(tag != null) {
					var originalTag:String = tag;
					tag = LuaUtils.formatVariable('tween_$tag');
					var variables = MusicBeatState.getVariables();
					variables.set(tag, FlxTween.color(target, duration, curColor, CoolUtil.colorFromString(targetColor), {
						ease: LuaUtils.getTweenEaseByString(ease),
						onComplete: function(twn:FlxTween) {
							variables.remove(tag);
							call('onTweenCompleted', [originalTag, vars]);
						}
					}));
					return tag;
				} else {
					FlxTween.color(target, duration, curColor, CoolUtil.colorFromString(targetColor), {ease: LuaUtils.getTweenEaseByString(ease)});
				}
			}
			return null;
		});
		Lua_helper.add_callback(lua, "cameraShake", function(camera:String, intensity:Float, duration:Float) {
			FlxG.camera.shake(intensity, duration);
		});
		Lua_helper.add_callback(lua, "cameraFlash", function(camera:String, color:String, duration:Float, forced:Bool) {
			FlxG.camera.flash(CoolUtil.colorFromString(color), duration, null, forced);
		});
		Lua_helper.add_callback(lua, "cameraFade", function(camera:String, color:String, duration:Float, forced:Bool, ?fadeOut:Bool = false) {
			FlxG.camera.fade(CoolUtil.colorFromString(color), duration, fadeOut, null, forced);
		});
		Lua_helper.add_callback(lua, "setCameraScroll", function(x:Float, y:Float) FlxG.camera.scroll.set(x - FlxG.width / 2, y - FlxG.height / 2));
		Lua_helper.add_callback(lua, "addCameraScroll", function(?x:Float = 0, ?y:Float = 0) FlxG.camera.scroll.add(x, y));
		Lua_helper.add_callback(lua, "getCameraScrollX", function() return FlxG.camera.scroll.x + FlxG.width / 2);
		Lua_helper.add_callback(lua, "getCameraScrollY", function() return FlxG.camera.scroll.y + FlxG.height / 2);
		Lua_helper.add_callback(lua, "getCameraScrollRawX", function() return FlxG.camera.scroll.x);
		Lua_helper.add_callback(lua, "getCameraScrollRawY", function() return FlxG.camera.scroll.y);
		Lua_helper.add_callback(lua, "getSave", function(key:String) {
			if(FlxG.save.data != null) return Reflect.getProperty(FlxG.save.data, key);
			return null;
		});
		Lua_helper.add_callback(lua, "setSave", function(key:String, value:Dynamic) {
			if(FlxG.save.data != null) Reflect.setProperty(FlxG.save.data, key, value);
		});
		Lua_helper.add_callback(lua, "flushSave", function() FlxG.save.flush());
		#if HSCRIPT_ALLOWED
		Lua_helper.add_callback(lua, "runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			initHaxeModuleCode(codeToRun, varsToBring);
			if(hscript != null)
			{
				var retVal = hscript.call(funcToRun, funcArgs);
				if(retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
				else if(hscript.returnValue != null)
				{
					return hscript.returnValue;
				}
			}
			return null;
		});
		Lua_helper.add_callback(lua, "runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null):Dynamic {
			if(hscript != null)
			{
				var retVal = hscript.call(funcToRun, funcArgs);
				if(retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
			}
			else
			{
				var pos:HScriptInfos = cast {fileName: scriptName, showLine: false, isLua: true};
				if(lastCalledFunction != '') pos.funcName = lastCalledFunction;
				Iris.error("runHaxeFunction: HScript has not been initialized yet! Use \"runHaxeCode\" to initialize it", pos);
			}
			return null;
		});
		Lua_helper.add_callback(lua, "addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			var str:String = '';
			if(libPackage.length > 0)
				str = libPackage + '.';
			else if(libName == null)
				libName = '';

			var c:Dynamic = Type.resolveClass(str + libName);
			if(c == null)
				c = Type.resolveEnum(str + libName);

			if(hscript == null)
				initHaxeModuleCode('', null);

			if(hscript != null)
			{
				var pos:HScriptInfos = cast {fileName: scriptName, showLine: false, isLua: true};
				if(lastCalledFunction != '') pos.funcName = lastCalledFunction;

				try {
					if(c != null) hscript.set(libName, c);
				}
				catch(e:IrisError) {
					Iris.error(Printer.errorToString(e, false), pos);
				}
			}
		});
		#end
	}

	function stateTweenFunction(tag:String, vars:String, tweenValue:Any, duration:Float, ease:String):Dynamic
	{
		var target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
		var variables = MusicBeatState.getVariables();
		if(target != null) {
			if(tag != null) {
				var originalTag:String = tag;
				tag = LuaUtils.formatVariable('tween_$tag');
				variables.set(tag, FlxTween.tween(target, tweenValue, duration, {
					ease: LuaUtils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						variables.remove(tag);
						call('onTweenCompleted', [originalTag, vars]);
					}
				}));
				return tag;
			} else {
				FlxTween.tween(target, tweenValue, duration, {ease: LuaUtils.getTweenEaseByString(ease)});
			}
		}
		return null;
	}

	public function funcExists(funcName:String):Bool
	{
		if(lua == null) return false;
		Lua.getglobal(lua, funcName);
		var type:Int = Lua.type(lua, -1);
		Lua.pop(lua, 1);
		return (type == Lua.LUA_TFUNCTION);
	}

	public function call(func:String, args:Array<Dynamic>):Dynamic
	{
		if(closed || lua == null) return LuaUtils.Function_Continue;
		try {
			Lua.getglobal(lua, func);
			var type:Int = Lua.type(lua, -1);
			if(type != Lua.LUA_TFUNCTION) {
				Lua.pop(lua, 1);
				return LuaUtils.Function_Continue;
			}
			for(arg in args) Convert.toLua(lua, arg);
			var status:Int = Lua.pcall(lua, args.length, 1, 0);
			if(status != Lua.LUA_OK) {
				var error:String = Lua.tostring(lua, -1);
				Lua.pop(lua, 1);
				trace('LoadingLuaScript error in $func: $error');
				return LuaUtils.Function_Continue;
			}
			var result:Dynamic = cast Convert.fromLua(lua, -1);
			if(result == null) result = LuaUtils.Function_Continue;
			Lua.pop(lua, 1);
			return result;
		} catch(e:Dynamic) {
			trace('LoadingLuaScript exception in $func: $e');
		}
		return LuaUtils.Function_Continue;
	}

	public function set(variable:String, data:Dynamic)
	{
		if(lua == null) return;
		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
	}

	public function destroy()
	{
		closed = true;
		if(lua != null)
		{
			Lua.close(lua);
			lua = null;
		}
		#if HSCRIPT_ALLOWED
		if(hscript != null)
		{
			hscript.destroy();
			hscript = null;
		}
		#end
		MusicBeatState.getVariables().remove('barBack');
		MusicBeatState.getVariables().remove('bar');
		loadingState = null;
	}

	#if HSCRIPT_ALLOWED
	function initHaxeModuleCode(code:String, ?varsToBring:Any = null)
	{
		if(hscript != null) {
			hscript.destroy();
			hscript = null;
		}
		try {
			hscript = new HScript(null, code, varsToBring);
			hscript.origin = scriptName;
			hscript.modFolder = modDirectory;
		}
		catch(e:IrisError) {
			var pos:HScriptInfos = cast {fileName: scriptName, isLua: true};
			if(lastCalledFunction != '') pos.funcName = lastCalledFunction;
			Iris.error(Printer.errorToString(e, false), pos);
			hscript = null;
		}
	}
	#end
}
#end