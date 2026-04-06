package backend;

import flixel.system.ui.FlxSoundTray;
import openfl.display.Bitmap;
import openfl.utils.Assets;
import openfl.display.BitmapData;

class FunkinSoundTray extends FlxSoundTray
{
	var graphicScale:Float = 0.30;
	var lerpYPos:Float = 0;
	var alphaTarget:Float = 0;

	var volumeMaxSound:String;
	var _lastMod:String = '';

	public function new()
	{
		super();
		_buildGraphics();
		trace("Custom sound tray initialized!");
	}

	function _getImageData(file:String):BitmapData
	{
		#if MODS_ALLOWED
		var modPath:String = Paths.mods(Mods.currentModDirectory + '/images/soundtray/' + file + '.png');
		if (sys.FileSystem.exists(modPath))
			return BitmapData.fromFile(modPath);
		for (mod in Mods.getGlobalMods())
		{
			var globalPath:String = Paths.mods(mod + '/images/soundtray/' + file + '.png');
			if (sys.FileSystem.exists(globalPath))
				return BitmapData.fromFile(globalPath);
		}
		#end
		return Assets.getBitmapData(Paths.getPath('images/soundtray/' + file + '.png', IMAGE));
	}

	function _getSoundPath(file:String):String
	{
		#if MODS_ALLOWED
		var modPath:String = Paths.mods(Mods.currentModDirectory + '/sounds/soundtray/' + file + '.ogg');
		if (sys.FileSystem.exists(modPath))
			return modPath;
		for (mod in Mods.getGlobalMods())
		{
			var globalPath:String = Paths.mods(mod + '/sounds/soundtray/' + file + '.ogg');
			if (sys.FileSystem.exists(globalPath))
				return globalPath;
		}
		#end
		return Paths.getPath('sounds/soundtray/' + file + '.ogg', SOUND);
	}

	function _buildGraphics()
	{
		removeChildren();

		var bg:Bitmap = new Bitmap(_getImageData('volumebox'));
		bg.scaleX = graphicScale;
		bg.scaleY = graphicScale;
		bg.smoothing = ClientPrefs.data.antialiasing;
		addChild(bg);

		y = -height;
		visible = false;

		var backingBar:Bitmap = new Bitmap(_getImageData('bars_10'));
		backingBar.x = 9;
		backingBar.y = 5;
		backingBar.scaleX = graphicScale;
		backingBar.scaleY = graphicScale;
		backingBar.smoothing = ClientPrefs.data.antialiasing;
		addChild(backingBar);
		backingBar.alpha = 0.4;

		_bars = [];

		for (i in 1...11)
		{
			var bar:Bitmap = new Bitmap(_getImageData('bars_' + i));
			bar.x = 9;
			bar.y = 5;
			bar.scaleX = graphicScale;
			bar.scaleY = graphicScale;
			bar.smoothing = ClientPrefs.data.antialiasing;
			addChild(bar);
			_bars.push(bar);
		}

		y = -height;
		screenCenter();

		volumeUpSound = _getSoundPath('Volup');
		volumeDownSound = _getSoundPath('Voldown');
		volumeMaxSound = _getSoundPath('VolMAX');

		_lastMod = Mods.currentModDirectory;
	}

	override public function update(MS:Float):Void
	{
		var elapsed:Float = MS / 1000;
		y = FlxMath.lerp(y, lerpYPos, 0.1);
		alpha = FlxMath.lerp(alpha, alphaTarget, 0.25);

		if (_timer > 0)
		{
			_timer -= (MS / 1000);
			alphaTarget = 1;
			lerpYPos = 10;
		}
		else
		{
			lerpYPos = -height - 10;
			alphaTarget = 0;
		}

		if (y <= -height && alpha <= 0.01)
		{
			visible = false;
			active = false;

			#if FLX_SAVE
			if (FlxG.save.isBound)
			{
				FlxG.save.data.mute = FlxG.sound.muted;
				FlxG.save.data.volume = FlxG.sound.volume;
				FlxG.save.flush();
			}
			#end
		}
	}

	override public function show(up:Bool = false):Void
	{
		if (Mods.currentModDirectory != _lastMod)
			_buildGraphics();

		_timer = 1;
		lerpYPos = 10;
		visible = true;
		active = true;
		if (parent != null)
			parent.setChildIndex(this, parent.numChildren - 1);
		var globalVolume:Int = Math.round(FlxG.sound.volume * 10);

		if (FlxG.sound.muted)
		{
			globalVolume = 0;
		}

		if (!silent)
		{
			var sound = up ? volumeUpSound : volumeDownSound;

			if (globalVolume == 10) sound = volumeMaxSound;

			if (sound != null) FlxG.sound.load(sound).play();
		}

		for (i in 0..._bars.length)
		{
			if (i < globalVolume)
			{
				_bars[i].visible = true;
			}
			else
			{
				_bars[i].visible = false;
			}
		}
	}
}