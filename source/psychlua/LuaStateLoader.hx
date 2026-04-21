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
import flixel.util.FlxSave;
import flixel.math.FlxMath;

import psychlua.LuaUtils;
import psychlua.LuaUtils.LuaTweenOptions;
import psychlua.ModchartSprite;
import psychlua.CustomSubstate;
import psychlua.ShaderFunctions;

import flixel.input.gamepad.FlxGamepadInputID;

import flixel.addons.display.FlxRuntimeShader;

#if DISCORD_ALLOWED
import backend.Discord.DiscordClient;
#end
#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end
#if TRANSLATIONS_ALLOWED
import backend.Language;
#end

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
			if(stateName == 'PlayState' && states.PlayState.SONG != null) {
				FlxG.state.persistentUpdate = false;
				states.LoadingState.loadAndSwitchState(new states.PlayState());
			} else {
				backend.StateManager.switchState(stateName);
			}
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

		Lua_helper.add_callback(lua, "loadSong", function(songName:String, ?difficulty:Dynamic = 'normal', ?folder:String = null) {
			var diffIdx:Int = 0;
			var resolvedDiff:String = 'normal';
			if(Std.isOfType(difficulty, Int)) {
				diffIdx = cast(difficulty, Int);
				if(diffIdx < 0 || diffIdx >= backend.Difficulty.list.length) diffIdx = 0;
				if(backend.Difficulty.list.length > 0)
					resolvedDiff = backend.Difficulty.list[diffIdx];
			} else if(Std.isOfType(difficulty, String)) {
				resolvedDiff = cast(difficulty, String);
				var diffLower:String = resolvedDiff.toLowerCase();
				var idx:Int = -1;
				for(i in 0...backend.Difficulty.list.length) {
					if(backend.Difficulty.list[i].toLowerCase() == diffLower) { idx = i; break; }
				}
				if(idx >= 0) diffIdx = idx;
			}
			var songFolder:String = folder != null ? Paths.formatToSongPath(folder) : Paths.formatToSongPath(songName);
			var jsonName:String = Paths.formatToSongPath(songName) + '-' + Paths.formatToSongPath(resolvedDiff);
			var chartCheck = backend.Song.getChart(jsonName, songFolder);
			if(chartCheck == null)
				jsonName = Paths.formatToSongPath(songName);
			if(backend.Song.getChart(jsonName, songFolder) != null) {
				backend.Song.loadFromJson(jsonName, songFolder);
				states.PlayState.isStoryMode = false;
				states.PlayState.storyDifficulty = diffIdx;
				states.PlayState.previousState = stateName;
				FlxG.state.persistentUpdate = false;
				states.LoadingState.loadAndSwitchState(new states.PlayState());
			}
		});

		Lua_helper.add_callback(lua, "songExists", function(songName:String, ?difficulty:Dynamic = null, ?folder:String = null):Bool {
			var songFolder:String = folder != null ? Paths.formatToSongPath(folder) : Paths.formatToSongPath(songName);
			if(difficulty != null) {
				var resolvedDiff:String = 'normal';
				if(Std.isOfType(difficulty, Int)) {
					var idx:Int = cast(difficulty, Int);
					if(idx >= 0 && idx < backend.Difficulty.list.length)
						resolvedDiff = backend.Difficulty.list[idx].toLowerCase();
				} else if(Std.isOfType(difficulty, String)) {
					resolvedDiff = cast(difficulty, String).toLowerCase();
				}
				var jsonName:String = Paths.formatToSongPath(songName) + '-' + resolvedDiff;
				if(backend.Song.getChart(jsonName, songFolder) != null) return true;
			}
			return backend.Song.getChart(Paths.formatToSongPath(songName), songFolder) != null;
		});

		Lua_helper.add_callback(lua, "getSongDifficulties", function(songName:String, ?folder:String = null):Array<String> {
			var result:Array<String> = [];
			#if MODS_ALLOWED
			var songFolder:String = folder != null ? Paths.formatToSongPath(folder) : Paths.formatToSongPath(songName);
			var dirPath:String = Paths.mods(Mods.currentModDirectory + '/data/' + songFolder + '/');
			if(FileSystem.exists(dirPath) && FileSystem.isDirectory(dirPath)) {
				var prefix:String = Paths.formatToSongPath(songName) + '-';
				for(file in FileSystem.readDirectory(dirPath)) {
					if(file.endsWith('.json')) {
						var base:String = file.substr(0, file.length - 5);
						if(base.startsWith(prefix))
							result.push(base.substr(prefix.length));
					}
				}
			}
			#end
			return result;
		});

		Lua_helper.add_callback(lua, "getCurrentSong", function():String {
			if(states.PlayState.SONG != null)
				return states.PlayState.SONG.song;
			return null;
		});

		Lua_helper.add_callback(lua, "getHighscore", function(songName:String, ?difficulty:Dynamic = 'normal'):Int {
			var diffIdx:Int = 0;
			if(Std.isOfType(difficulty, Int)) {
				diffIdx = cast(difficulty, Int);
				if(diffIdx < 0 || diffIdx >= backend.Difficulty.list.length) diffIdx = 0;
			} else if(Std.isOfType(difficulty, String)) {
				var diffStr:String = cast(difficulty, String).toLowerCase();
				for(i in 0...backend.Difficulty.list.length) {
					if(backend.Difficulty.list[i].toLowerCase() == diffStr) { diffIdx = i; break; }
				}
			}
			return backend.Highscore.getScore(songName, diffIdx);
		});

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

		Lua_helper.add_callback(lua, "flxRandomInt", function(min:Int, max:Int, ?exclude:Any = null) {
			var excludeArray:Array<Int> = exclude == null ? [] : exclude;
			return FlxG.random.int(min, max, excludeArray);
		});
		Lua_helper.add_callback(lua, "flxRandomFloat", function(min:Float, max:Float, ?exclude:Any = null) {
			var excludeArray:Array<Float> = exclude == null ? [] : exclude;
			return FlxG.random.float(min, max, excludeArray);
		});
		Lua_helper.add_callback(lua, "flxRandomBool", function(?chance:Float = 50) {
			return FlxG.random.bool(chance);
		});

		Lua_helper.add_callback(lua, "getColorFromName", function(color:String) return FlxColor.fromString(color));

		Lua_helper.add_callback(lua, "getGraphicMidpointX", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getGraphicMidpoint().x;
			return 0;
		});
		Lua_helper.add_callback(lua, "getGraphicMidpointY", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(obj != null) return obj.getGraphicMidpoint().y;
			return 0;
		});

		Lua_helper.add_callback(lua, "loadMultipleFrames", function(variable:String, images:Array<String>) {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(spr != null && images != null && images.length > 0)
				spr.frames = Paths.getMultiAtlas(images);
		});

		Lua_helper.add_callback(lua, "luaSoundExists", function(tag:String) {
			var obj:FlxSound = MusicBeatState.getVariables().get('sound_$tag');
			return (obj != null && Std.isOfType(obj, FlxSound));
		});

		Lua_helper.add_callback(lua, "soundFadeIn", function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.fadeIn(duration, fromValue, toValue);
			}
		});
		Lua_helper.add_callback(lua, "soundFadeOut", function(tag:String, duration:Float, toValue:Float = 0) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.fadeOut(duration, toValue);
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.fadeOut(duration, toValue);
			}
		});
		Lua_helper.add_callback(lua, "soundFadeCancel", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null && FlxG.sound.music.fadeTween != null)
					FlxG.sound.music.fadeTween.cancel();
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null && snd.fadeTween != null) snd.fadeTween.cancel();
			}
		});
		Lua_helper.add_callback(lua, "getSoundVolume", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) return FlxG.sound.music.volume;
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) return snd.volume;
			}
			return 0;
		});
		Lua_helper.add_callback(lua, "setSoundVolume", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.volume = value;
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.volume = value;
			}
		});
		Lua_helper.add_callback(lua, "getSoundTime", function(tag:String) {
			if(tag == null || tag.length < 1)
				return FlxG.sound.music != null ? FlxG.sound.music.time : 0;
			tag = LuaUtils.formatVariable('sound_$tag');
			var snd:FlxSound = MusicBeatState.getVariables().get(tag);
			return snd != null ? snd.time : 0;
		});
		Lua_helper.add_callback(lua, "setSoundTime", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) FlxG.sound.music.time = value;
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.time = value;
			}
		});
		Lua_helper.add_callback(lua, "getSoundPitch", function(tag:String) {
			#if FLX_PITCH
			tag = LuaUtils.formatVariable('sound_$tag');
			var snd:FlxSound = MusicBeatState.getVariables().get(tag);
			return snd != null ? snd.pitch : 1;
			#else
			return 1;
			#end
		});
		Lua_helper.add_callback(lua, "setSoundPitch", function(tag:String, value:Float, ?doPause:Bool = false) {
			#if FLX_PITCH
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					var wasResumed:Bool = FlxG.sound.music.playing;
					if(doPause) FlxG.sound.music.pause();
					FlxG.sound.music.pitch = value;
					if(doPause && wasResumed) FlxG.sound.music.play();
				}
			} else {
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) {
					var wasResumed:Bool = snd.playing;
					if(doPause) snd.pause();
					snd.pitch = value;
					if(doPause && wasResumed) snd.play();
				}
			}
			#end
		});

		Lua_helper.add_callback(lua, "doTweenZoom", function(tag:String, camera:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			var cam:FlxCamera = FlxG.camera;
			var camObj:Dynamic = MusicBeatState.getVariables().get(camera);
			if(camObj != null && Std.isOfType(camObj, FlxCamera)) cam = cast camObj;
			var variables = MusicBeatState.getVariables();
			if(tag != null) {
				var originalTag:String = tag;
				tag = LuaUtils.formatVariable('tween_$tag');
				variables.set(tag, FlxTween.tween(cam, {zoom: value}, duration, {
					ease: LuaUtils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						variables.remove(tag);
						call('onTweenCompleted', [originalTag, camera]);
					}
				}));
				return tag;
			} else {
				FlxTween.tween(cam, {zoom: value}, duration, {ease: LuaUtils.getTweenEaseByString(ease)});
			}
			return null;
		});

		Lua_helper.add_callback(lua, "setReturnState", function(stateName:String) {
			PlayState.returnAfterSongState = stateName;
		});
		Lua_helper.add_callback(lua, "getReturnState", function() {
			return PlayState.returnAfterSongState;
		});

		Lua_helper.add_callback(lua, "close", function() {
			closed = true;
		});

		var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();

		Lua_helper.add_callback(lua, "initLuaShader", function(name:String) {
			if(!ClientPrefs.data.shaders) return false;
			#if MODS_ALLOWED
			if(runtimeShaders.exists(name)) {
				var shaderData:Array<String> = runtimeShaders.get(name);
				if(shaderData != null && (shaderData[0] != null || shaderData[1] != null))
					return true;
			}
			var foldersToCheck:Array<String> = [Paths.getSharedPath('shaders/')];
			foldersToCheck.push(Paths.mods('shaders/'));
			if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
				foldersToCheck.insert(0, Paths.mods(Mods.currentModDirectory + '/shaders/'));
			for(mod in Mods.getGlobalMods())
				foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
			for(folder in foldersToCheck) {
				if(FileSystem.exists(folder)) {
					var frag:String = folder + name + '.frag';
					var vert:String = folder + name + '.vert';
					var found:Bool = false;
					if(FileSystem.exists(frag)) { frag = File.getContent(frag); found = true; } else frag = null;
					if(FileSystem.exists(vert)) { vert = File.getContent(vert); found = true; } else vert = null;
					if(found) { runtimeShaders.set(name, [frag, vert]); return true; }
				}
			}
			#end
			return false;
		});
		Lua_helper.add_callback(lua, "setSpriteShader", function(obj:String, shader:String) {
			if(!ClientPrefs.data.shaders) return false;
			if(!runtimeShaders.exists(shader)) return false;
			#if (!flash && MODS_ALLOWED && sys)
			if(ShaderFunctions.isCamera(obj)) {
				var cam:FlxCamera = ShaderFunctions.getCameraByName(obj);
				var arr:Array<String> = runtimeShaders.get(shader);
				var rShader:FlxRuntimeShader = new shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
				ShaderFunctions.cameraShaders.set(obj, rShader);
				cam.setFilters([new openfl.filters.ShaderFilter(cast rShader)]);
				return true;
			}
			#end
			var split:Array<String> = obj.split('.');
			var leObj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				leObj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(leObj != null) {
				var arr:Array<String> = runtimeShaders.get(shader);
				leObj.shader = new shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "removeSpriteShader", function(obj:String) {
			#if (!flash && MODS_ALLOWED && sys)
			if(ShaderFunctions.isCamera(obj)) {
				var cam:FlxCamera = ShaderFunctions.getCameraByName(obj);
				ShaderFunctions.cameraShaders.remove(obj);
				cam.setFilters([]);
				return true;
			}
			#end
			var split:Array<String> = obj.split('.');
			var leObj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1)
				leObj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]);
			if(leObj != null) { leObj.shader = null; return true; }
			return false;
		});
		Lua_helper.add_callback(lua, "setShaderFloat", function(obj:String, prop:String, value:Float) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			shader.setFloat(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderFloat", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			return shader == null ? null : shader.getFloat(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderInt", function(obj:String, prop:String, value:Int) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			shader.setInt(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderInt", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			return shader == null ? null : shader.getInt(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderBool", function(obj:String, prop:String, value:Bool) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			shader.setBool(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderBool", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			return shader == null ? null : shader.getBool(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderFloatArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			shader.setFloatArray(prop, values);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderFloatArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) { trace('getShaderFloatArray: Shader is not FlxRuntimeShader!'); return null; }
			return shader.getFloatArray(prop);
			#else
			trace('getShaderFloatArray: Platform unsupported for Runtime Shaders!');
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderIntArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			shader.setIntArray(prop, values);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderIntArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) { trace('getShaderIntArray: Shader is not FlxRuntimeShader!'); return null; }
			return shader.getIntArray(prop);
			#else
			trace('getShaderIntArray: Platform unsupported for Runtime Shaders!');
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderBoolArray", function(obj:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			shader.setBoolArray(prop, values);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getShaderBoolArray", function(obj:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) { trace('getShaderBoolArray: Shader is not FlxRuntimeShader!'); return null; }
			return shader.getBoolArray(prop);
			#else
			trace('getShaderBoolArray: Platform unsupported for Runtime Shaders!');
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setShaderSampler2D", function(obj:String, prop:String, bitmapdataPath:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(obj);
			if(shader == null) return false;
			var value = Paths.image(bitmapdataPath);
			if(value != null && value.bitmap != null) { shader.setSampler2D(prop, value.bitmap); return true; }
			return false;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShader", function(camera:String, shader:String) {
			if(!ClientPrefs.data.shaders) return false;
			if(!runtimeShaders.exists(shader)) return false;
			#if (!flash && MODS_ALLOWED && sys)
			var cam:FlxCamera = ShaderFunctions.getCameraByName(camera);
			var arr:Array<String> = runtimeShaders.get(shader);
			var rShader:FlxRuntimeShader = new shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
			ShaderFunctions.cameraShaders.set(camera, rShader);
			cam.setFilters([new openfl.filters.ShaderFilter(cast rShader)]);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "removeCameraShader", function(camera:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var cam:FlxCamera = ShaderFunctions.getCameraByName(camera);
			ShaderFunctions.cameraShaders.remove(camera);
			cam.setFilters([]);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderFloat", function(camera:String, prop:String, value:Float) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			if(shader == null) return false;
			shader.setFloat(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getCameraShaderFloat", function(camera:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			return shader == null ? null : shader.getFloat(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderInt", function(camera:String, prop:String, value:Int) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			if(shader == null) return false;
			shader.setInt(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getCameraShaderInt", function(camera:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			return shader == null ? null : shader.getInt(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderBool", function(camera:String, prop:String, value:Bool) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			if(shader == null) return false;
			shader.setBool(prop, value);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getCameraShaderBool", function(camera:String, prop:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			return shader == null ? null : shader.getBool(prop);
			#else
			return null;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderFloatArray", function(camera:String, prop:String, values:Dynamic) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			if(shader == null) return false;
			shader.setFloatArray(prop, values);
			return true;
			#else
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "setCameraShaderSampler2D", function(camera:String, prop:String, bitmapdataPath:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.cameraShaders.get(camera);
			if(shader == null) return false;
			var value = Paths.image(bitmapdataPath);
			if(value != null && value.bitmap != null) { shader.setSampler2D(prop, value.bitmap); return true; }
			return false;
			#else
			return false;
			#end
		});

		Lua_helper.add_callback(lua, "getRunningScripts", function() {
			var result:Array<String> = [stateName];
			if(PlayState.instance != null)
				for(script in PlayState.instance.luaArray)
					result.push(script.scriptName);
			return result;
		});
		Lua_helper.add_callback(lua, "setOnScripts", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			set(varName, arg);
			if(PlayState.instance != null)
				PlayState.instance.setOnScripts(varName, arg, exclusions);
		});
		Lua_helper.add_callback(lua, "setOnHScript", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			#if HSCRIPT_ALLOWED
			if(hscript != null) hscript.set(varName, arg);
			#end
			if(PlayState.instance != null)
				PlayState.instance.setOnHScript(varName, arg, exclusions);
		});
		Lua_helper.add_callback(lua, "setOnLuas", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			set(varName, arg);
			if(PlayState.instance != null)
				PlayState.instance.setOnLuas(varName, arg, exclusions);
		});
		Lua_helper.add_callback(lua, "callOnScripts", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops:Bool = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(args == null) args = [];
			if(excludeScripts == null) excludeScripts = [];
			if(PlayState.instance != null)
				return PlayState.instance.callOnScripts(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return call(funcName, args);
		});
		Lua_helper.add_callback(lua, "callOnLuas", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops:Bool = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(args == null) args = [];
			if(excludeScripts == null) excludeScripts = [];
			if(PlayState.instance != null)
				return PlayState.instance.callOnLuas(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return call(funcName, args);
		});
		Lua_helper.add_callback(lua, "callOnHScript", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops:Bool = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(args == null) args = [];
			if(excludeScripts == null) excludeScripts = [];
			if(PlayState.instance != null)
				return PlayState.instance.callOnHScript(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return LuaUtils.Function_Continue;
		});
		Lua_helper.add_callback(lua, "callScript", function(luaFile:String, funcName:String, ?args:Array<Dynamic> = null) {
			if(args == null) args = [];
			if(PlayState.instance != null) {
				for(luaInstance in PlayState.instance.luaArray)
					if(luaInstance.scriptName == luaFile)
						return luaInstance.call(funcName, args);
			}
			return null;
		});
		Lua_helper.add_callback(lua, "isRunning", function(scriptFile:String) {
			if(PlayState.instance != null) {
				for(luaInstance in PlayState.instance.luaArray)
					if(luaInstance.scriptName == scriptFile)
						return true;
				#if HSCRIPT_ALLOWED
				for(hscriptInstance in PlayState.instance.hscriptArray)
					if(hscriptInstance.origin == scriptFile)
						return true;
				#end
			}
			return (lua != null && !closed);
		});
		Lua_helper.add_callback(lua, "addLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) {
			if(PlayState.instance != null) {
				if(!ignoreAlreadyRunning)
					for(luaInstance in PlayState.instance.luaArray)
						if(luaInstance.scriptName == luaFile) return;
				new FunkinLua(luaFile);
			}
		});
		Lua_helper.add_callback(lua, "addHScript", function(scriptFile:String, ?ignoreAlreadyRunning:Bool = false) {
			#if HSCRIPT_ALLOWED
			if(PlayState.instance != null) {
				if(!ignoreAlreadyRunning)
					for(script in PlayState.instance.hscriptArray)
						if(script.origin == scriptFile) return;
				PlayState.instance.initHScript(scriptFile);
			}
			#end
		});
		Lua_helper.add_callback(lua, "removeLuaScript", function(luaFile:String) {
			if(PlayState.instance != null) {
				for(luaInstance in PlayState.instance.luaArray) {
					if(luaInstance.scriptName == luaFile) {
						luaInstance.stop();
						return true;
					}
				}
			}
			return false;
		});
		Lua_helper.add_callback(lua, "removeHScript", function(scriptFile:String) {
			#if HSCRIPT_ALLOWED
			if(PlayState.instance != null) {
				for(script in PlayState.instance.hscriptArray) {
					if(script.origin == scriptFile) {
						script.destroy();
						return true;
					}
				}
			}
			#end
			return false;
		});

		Lua_helper.add_callback(lua, "getTextFromFile", function(path:String, ?ignoreModFolders:Bool = false) {
			return Paths.getTextFromFile(path, ignoreModFolders);
		});
		Lua_helper.add_callback(lua, "saveFile", function(path:String, content:String, ?absolute:Bool = false) {
			try {
				#if MODS_ALLOWED
				if(!absolute)
					File.saveContent(Paths.mods(path), content);
				else
				#end
					File.saveContent(path, content);
				return true;
			} catch(e:Dynamic) {
				trace('saveFile: Error trying to save ' + path + ': ' + e);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "deleteFile", function(path:String, ?ignoreModFolders:Bool = false, ?absolute:Bool = false) {
			try {
				var lePath:String = path;
				if(!absolute) lePath = Paths.getPath(path, TEXT, !ignoreModFolders);
				if(FileSystem.exists(lePath)) {
					FileSystem.deleteFile(lePath);
					return true;
				}
			} catch(e:Dynamic) {
				trace('deleteFile: Error trying to delete ' + path + ': ' + e);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "checkFileExists", function(filename:String, ?absolute:Bool = false) {
			#if MODS_ALLOWED
			if(absolute) return FileSystem.exists(filename);
			return FileSystem.exists(Paths.getPath(filename, TEXT));
			#else
			if(absolute) return openfl.utils.Assets.exists(filename, TEXT);
			return openfl.utils.Assets.exists(Paths.getPath(filename, TEXT));
			#end
		});
		Lua_helper.add_callback(lua, "directoryFileList", function(folder:String) {
			#if sys
			if(sys.FileSystem.exists(folder) && sys.FileSystem.isDirectory(folder))
				return sys.FileSystem.readDirectory(folder);
			#end
			return [];
		});
		Lua_helper.add_callback(lua, "initSaveData", function(name:String, ?folder:String = 'psychenginemods') {
			var variables = MusicBeatState.getVariables();
			if(!variables.exists('save_$name')) {
				var save:flixel.util.FlxSave = new flixel.util.FlxSave();
				save.bind(name, CoolUtil.getSavePath() + '/' + folder);
				variables.set('save_$name', save);
				return;
			}
			trace('initSaveData: Save file already initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "eraseSaveData", function(name:String) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				variables.get('save_$name').erase();
				return;
			}
			trace('eraseSaveData: Save file not initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "flushSaveData", function(name:String) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				variables.get('save_$name').flush();
				return;
			}
			trace('flushSaveData: Save file not initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "getDataFromSave", function(name:String, field:String, ?defaultValue:Dynamic = null) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				var saveData = variables.get('save_$name').data;
				if(Reflect.hasField(saveData, field))
					return Reflect.field(saveData, field);
				else
					return defaultValue;
			}
			trace('getDataFromSave: Save file not initialized: ' + name);
			return defaultValue;
		});
		Lua_helper.add_callback(lua, "setDataFromSave", function(name:String, field:String, value:Dynamic) {
			var variables = MusicBeatState.getVariables();
			if(variables.exists('save_$name')) {
				Reflect.setField(variables.get('save_$name').data, field, value);
				return;
			}
			trace('setDataFromSave: Save file not initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "stringStartsWith", function(str:String, start:String) {
			return str.startsWith(start);
		});
		Lua_helper.add_callback(lua, "stringEndsWith", function(str:String, end:String) {
			return str.endsWith(end);
		});
		Lua_helper.add_callback(lua, "stringSplit", function(str:String, split:String) {
			return str.split(split);
		});
		Lua_helper.add_callback(lua, "stringTrim", function(str:String) {
			return str.trim();
		});
		Lua_helper.add_callback(lua, "getRandomBool", function(chance:Float = 50) {
			return FlxG.random.bool(chance);
		});
		Lua_helper.add_callback(lua, "getRandomFloat", function(min:Float, max:Float = 1, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Float> = [];
			for(i in 0...excludeArray.length) {
				if(exclude == '') break;
				toExclude.push(Std.parseFloat(excludeArray[i].trim()));
			}
			return FlxG.random.float(min, max, toExclude);
		});
		Lua_helper.add_callback(lua, "getRandomInt", function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Int> = [];
			for(i in 0...excludeArray.length) {
				if(exclude == '') break;
				toExclude.push(Std.parseInt(excludeArray[i].trim()));
			}
			return FlxG.random.int(min, max, toExclude);
		});
		Lua_helper.add_callback(lua, "openCustomSubstate", function(name:String, ?pauseGame:Bool = false) {
			CustomSubstate.openCustomSubstate(name, pauseGame);
		});
		Lua_helper.add_callback(lua, "closeCustomSubstate", function() {
			return CustomSubstate.closeCustomSubstate();
		});
		Lua_helper.add_callback(lua, "insertToCustomSubstate", function(tag:String, ?pos:Int = -1) {
			return CustomSubstate.insertToCustomSubstate(tag, pos);
		});
		#if DISCORD_ALLOWED
		Lua_helper.add_callback(lua, "changeDiscordPresence", DiscordClient.changePresence);
		Lua_helper.add_callback(lua, "changeDiscordClientID", function(?newID:String) {
			if(newID == null) DiscordClient.resetClientID();
			else DiscordClient.clientID = newID;
		});
		#end
		#if ACHIEVEMENTS_ALLOWED
		Lua_helper.add_callback(lua, "achievementExists", function(name:String) return Achievements.achievements.exists(name));
		Lua_helper.add_callback(lua, "getAchievementScore", function(name:String):Float {
			if(!Achievements.achievements.exists(name)) {
				trace('getAchievementScore: Couldnt find achievement: $name');
				return -1;
			}
			return Achievements.getScore(name);
		});
		Lua_helper.add_callback(lua, "setAchievementScore", function(name:String, ?value:Float = 0, ?saveIfNotUnlocked:Bool = true):Float {
			if(!Achievements.achievements.exists(name)) {
				trace('setAchievementScore: Couldnt find achievement: $name');
				return -1;
			}
			return Achievements.setScore(name, value, saveIfNotUnlocked);
		});
		Lua_helper.add_callback(lua, "addAchievementScore", function(name:String, ?value:Float = 1, ?saveIfNotUnlocked:Bool = true):Float {
			if(!Achievements.achievements.exists(name)) {
				trace('addAchievementScore: Couldnt find achievement: $name');
				return -1;
			}
			return Achievements.addScore(name, value, saveIfNotUnlocked);
		});
		Lua_helper.add_callback(lua, "unlockAchievement", function(name:String):Dynamic {
			if(!Achievements.achievements.exists(name)) {
				trace('unlockAchievement: Couldnt find achievement: $name');
				return null;
			}
			return Achievements.unlock(name);
		});
		Lua_helper.add_callback(lua, "isAchievementUnlocked", function(name:String):Dynamic {
			if(!Achievements.achievements.exists(name)) {
				trace('isAchievementUnlocked: Couldnt find achievement: $name');
				return null;
			}
			return Achievements.isUnlocked(name);
		});
		#end
		#if TRANSLATIONS_ALLOWED
		Lua_helper.add_callback(lua, "getTranslationPhrase", function(key:String, ?defaultPhrase:String, ?values:Array<Dynamic> = null) {
			return Language.getPhrase(key, defaultPhrase, values);
		});
		Lua_helper.add_callback(lua, "getFileTranslation", function(key:String) {
			return Language.getFileTranslation(key);
		});
		Lua_helper.add_callback(lua, "setTranslationPhrase", function(key:String, value:String) {
			Language.setPhrase(key, value);
		});
		Lua_helper.add_callback(lua, "setFileTranslation", function(key:String, value:String) {
			Language.setFileTranslation(key, value);
		});
		#end
		Lua_helper.add_callback(lua, "addCharacterToList", function(name:String, type:String) {
			if(PlayState.instance == null) return;
			var charType:Int = 0;
			switch(type.toLowerCase()) {
				case 'dad': charType = 1;
				case 'gf' | 'girlfriend': charType = 2;
			}
			PlayState.instance.addCharacterToList(name, charType);
		});
		Lua_helper.add_callback(lua, "getCharacterX", function(type:String) {
			if(PlayState.instance == null) return 0.0;
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent': return PlayState.instance.dadGroup.x;
				case 'gf' | 'girlfriend': return PlayState.instance.gfGroup.x;
				default: return PlayState.instance.boyfriendGroup.x;
			}
		});
		Lua_helper.add_callback(lua, "setCharacterX", function(type:String, value:Float) {
			if(PlayState.instance == null) return;
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent': PlayState.instance.dadGroup.x = value;
				case 'gf' | 'girlfriend': PlayState.instance.gfGroup.x = value;
				default: PlayState.instance.boyfriendGroup.x = value;
			}
		});
		Lua_helper.add_callback(lua, "getCharacterY", function(type:String) {
			if(PlayState.instance == null) return 0.0;
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent': return PlayState.instance.dadGroup.y;
				case 'gf' | 'girlfriend': return PlayState.instance.gfGroup.y;
				default: return PlayState.instance.boyfriendGroup.y;
			}
		});
		Lua_helper.add_callback(lua, "setCharacterY", function(type:String, value:Float) {
			if(PlayState.instance == null) return;
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent': PlayState.instance.dadGroup.y = value;
				case 'gf' | 'girlfriend': PlayState.instance.gfGroup.y = value;
				default: PlayState.instance.boyfriendGroup.y = value;
			}
		});
		Lua_helper.add_callback(lua, "characterDance", function(character:String) {
			if(PlayState.instance == null) return;
			switch(character.toLowerCase()) {
				case 'dad': PlayState.instance.dad.dance();
				case 'gf' | 'girlfriend':
					if(PlayState.instance.gf != null) PlayState.instance.gf.dance();
				default: PlayState.instance.boyfriend.dance();
			}
		});

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
			if(stateName == 'PlayState' && states.PlayState.SONG != null) {
				FlxG.state.persistentUpdate = false;
				states.LoadingState.loadAndSwitchState(new states.PlayState());
			} else {
				backend.StateManager.switchState(stateName);
			}
		});
		Lua_helper.add_callback(lua, "isMusicPlaying", function() {
			return FlxG.sound.music != null && FlxG.sound.music.playing;
		});
		Lua_helper.add_callback(lua, "getScore", function(songName:String, diffIndex:Int) {
			return backend.Highscore.getScore(songName, diffIndex);
		});
		Lua_helper.add_callback(lua, "getDifficulties", function(?weekName:String = null) {
			if(weekName != null && weekName.length > 0) {
				#if MODS_ALLOWED
				var weekPath = Paths.mods(Mods.currentModDirectory + '/weeks/' + weekName + '.json');
				if(FileSystem.exists(weekPath)) {
					var weekData:backend.WeekData = haxe.Json.parse(sys.io.File.getContent(weekPath));
					if(weekData != null) backend.Difficulty.loadFromWeek(weekData);
				}
				#end
			}
			if(backend.Difficulty.list == null || backend.Difficulty.list.length == 0)
				backend.Difficulty.resetList();
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