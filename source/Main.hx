package;

#if android
import android.content.Context;
#end

import debug.FPSCounter;

import flixel.graphics.FlxGraphic;
import flixel.FlxGame;
import flixel.FlxState;
import haxe.io.Path;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import lime.app.Application;
import states.InitialState;
import openfl.display.BitmapData;
import openfl.utils.ByteArray;
import openfl.display.PNGEncoderOptions;
import sys.io.File;
import sys.FileSystem;
import flixel.FlxG;
import flixel.tweens.FlxTween;

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import psychlua.HScript.HScriptInfos;
#end

#if (linux || mac)
import lime.graphics.Image;
#end

#if desktop
import backend.ALSoftConfig;
#end

#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#end

import backend.Highscore;

#if (cpp && windows)
import hxwindowmode.WindowColorMode;
#end

#if (linux && !debug)
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('#define GAMEMODE_AUTO')
#end

#if (cpp && windows)
@:cppFileCode('
	#include <windows.h>
	
	bool _detectWindowsDarkMode() {
		HKEY hKey;
		DWORD value = 0;
		DWORD dataSize = sizeof(DWORD);
		if (RegOpenKeyExA(HKEY_CURRENT_USER, "Software\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Themes\\\\Personalize", 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
			RegQueryValueExA(hKey, "AppsUseLightTheme", NULL, NULL, (LPBYTE)&value, &dataSize);
			RegCloseKey(hKey);
		}
		return (value == 0);
	}
')
#end

class Main extends Sprite
{
	public static final game = {
		width: 1280,
		height: 720,
		initialState: InitialState,
		framerate: 60,
		skipSplash: true,
		startFullscreen: false
	};

	public static var fpsVar:FPSCounter;
	public static var screenshotCounter:Int = 1;

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		#if (cpp && windows)
		backend.Native.fixScaling();
		#end

		#if android
		Sys.setCwd(Path.addTrailingSlash(Context.getExternalFilesDir()));
		#elseif ios
		Sys.setCwd(lime.system.System.applicationStorageDirectory);
		#end
		#if VIDEOS_ALLOWED
		hxvlc.util.Handle.init(#if (hxvlc >= "1.8.0")  ['--no-lua'] #end);
		#end

		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end

		FlxG.save.bind('funkin', CoolUtil.getSavePath());
		
		#if MODS_ALLOWED
		var save = FlxG.save;
		if(save != null && save.data != null)
		{
			var modMode:String = save.data.modMode;
			if(modMode == null || modMode == 'SINGLE MOD')
			{
				if(save.data.currentMod != null && save.data.currentMod != '')
				{
					Mods.currentModDirectory = save.data.currentMod;
				}
				else
				{
					Mods.loadTopMod();
				}
			}
			else if(modMode == 'DISABLE MODS')
			{
				Mods.currentModDirectory = '';
			}
			else
			{
				Mods.currentModDirectory = '';
				Mods.loadTopMod();
			}
		}
		else
		{
			Mods.loadTopMod();
		}
		#else
		Mods.loadTopMod();
		#end
		
		Highscore.load();

		#if HSCRIPT_ALLOWED
		Iris.warn = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(WARN, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('WARNING: $msgInfo', FlxColor.YELLOW);
		}
		Iris.error = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(ERROR, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('ERROR: $msgInfo', FlxColor.RED);
		}
		Iris.fatal = function(x, ?pos:haxe.PosInfos) {
			Iris.logLevel(FATAL, x, pos);
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			msgInfo += ' $x';
			if (PlayState.instance != null)
				PlayState.instance.addTextToDebug('FATAL: $msgInfo', 0xFFBB0000);
		}
		#end

		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end
		Controls.instance = new Controls();
		ClientPrefs.loadDefaultKeys();
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end
		var gameObject = new FlxGame(game.width, game.height, game.initialState, game.framerate, game.framerate, game.skipSplash, game.startFullscreen);
		@:privateAccess
		gameObject._customSoundTray = backend.FunkinSoundTray;
		addChild(gameObject);

		ClientPrefs.loadPrefs();

		#if !mobile
		fpsVar = new FPSCounter(10, 10, 0xFFFFFF);
		fpsVar.preloadBothModes();
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		ClientPrefs.updateFPSCounter();
		#end

		#if (linux || mac)
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end

		#if (cpp && windows)
		updateWindowTheme();
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];
		FlxG.stage.addEventListener(openfl.events.KeyboardEvent.KEY_DOWN, onKeyDown);
		
		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		FlxG.signals.gameResized.add(function (w, h) {
		     if (FlxG.cameras != null) {
			   for (cam in FlxG.cameras.list) {
				if (cam != null && cam.filters != null)
					resetSpriteCache(cam.flashSprite);
			   }
			}

			if (FlxG.game != null)
			resetSpriteCache(FlxG.game);
		});
	}

	static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
		        sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	function onKeyDown(event:openfl.events.KeyboardEvent):Void {
		var screenshotKeys = ClientPrefs.keyBinds.get('screenshot');
		if (screenshotKeys != null) {
			for (key in screenshotKeys) {
				if (event.keyCode == key) {
					takeScreenshot();
					break;
				}
			}
		}
	}

	function takeScreenshot():Void {
		var screenshotPath:String = "./screenshots/";
		
		if (!FileSystem.exists(screenshotPath)) {
			FileSystem.createDirectory(screenshotPath);
		}
		
		while (FileSystem.exists(screenshotPath + "screenshot_" + screenshotCounter + ".png")) {
			screenshotCounter++;
		}
		
		var fileName:String = screenshotPath + "screenshot_" + screenshotCounter + ".png";
		
		var image = FlxG.game.stage.window.readPixels();
		var bytes = image.encode(lime.graphics.ImageFileFormat.PNG);
		File.saveBytes(fileName, bytes);
		
		var flashSprite = new Sprite();
		var flashBitmap = new openfl.display.Bitmap(new BitmapData(Std.int(FlxG.stage.stageWidth), Std.int(FlxG.stage.stageHeight), false, 0xFFFFFFFF));
		flashSprite.addChild(flashBitmap);
		flashSprite.alpha = 1;
		FlxG.stage.addChild(flashSprite);
		
		var flashTween = FlxTween.tween(flashSprite, {alpha: 0}, 0.15, {
			onComplete: function(t:FlxTween) {
				FlxG.stage.removeChild(flashSprite);
			}
		});
		
		FlxG.sound.play(Paths.sound('screenshot'), 0.4);
		
		trace("Screenshot saved: " + fileName);
	}

	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "PsychEngine_" + dateNow + ".txt";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error;
		#if officialBuild
		errMsg += "\nPlease report this error to the GitHub page: https://github.com/ShadowMario/FNF-PsychEngine";
		#end
		errMsg += "\n\n> Crash Handler written by: sqirra-rng";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end
		Sys.exit(1);
	}
	#end

	#if (cpp && windows)
	@:functionCode('return _detectWindowsDarkMode();')
	static function detectWindowsDarkMode():Bool {
		return false;
	}

	public static function updateWindowTheme():Void {
		var isDark:Bool = false;
		
		switch(ClientPrefs.data.windowTheme) {
			case 'PC Theme':
				isDark = detectWindowsDarkMode();
			case 'White':
				isDark = false;
			case 'Dark':
				isDark = true;
		}
		
		if(ClientPrefs.data.windowColor == 'Default') {
			WindowColorMode.setWindowColorMode(isDark);
		} else {
			var color:Array<Int> = getWindowColor(ClientPrefs.data.windowColor);
			WindowColorMode.setWindowBorderColor(color, true, true);
		}
		
		WindowColorMode.redrawWindowHeader();
	}

	static function getWindowColor(colorName:String):Array<Int> {
		return switch(colorName) {
			case 'Red': [255, 0, 0];
			case 'Orange': [255, 165, 0];
			case 'Yellow': [255, 255, 0];
			case 'Green': [0, 255, 0];
			case 'Cyan': [0, 255, 255];
			case 'Blue': [0, 0, 255];
			case 'Purple': [128, 0, 128];
			case 'Pink': [255, 192, 203];
			case 'Grey': [128, 128, 128];
			default: [255, 255, 255];
		}
	}

	public static function applyModWindowColor():Void {
		if(!ClientPrefs.data.allowModWindowColor) {
			updateWindowTheme();
			return;
		}

		#if MODS_ALLOWED
		try {
			var pack:Dynamic = Mods.getPack();
			if(pack != null && pack.windowColor != null) {
				if(Std.isOfType(pack.windowColor, String)) {
					var colorString:String = cast pack.windowColor;
					if(colorString == "PC Theme" || colorString == "Default") {
						updateWindowTheme();
						return;
					}
				}
				else if(Std.isOfType(pack.windowColor, Array)) {
					var color:Array<Int> = pack.windowColor;
					if(color != null && color.length >= 3) {
						WindowColorMode.setWindowBorderColor([color[0], color[1], color[2]], true, true);
						WindowColorMode.redrawWindowHeader();
						return;
					}
				}
			}
		} catch(e:Dynamic) {
			trace('Error loading mod window color: ' + e);
		}
		#end

		updateWindowTheme();
	}
	#end
}