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

	public function new()
	{
		super();
		
		removeChildren();

		var bg:Bitmap = new Bitmap(Assets.getBitmapData(Paths.getPath('images/soundtray/volumebox.png', IMAGE)));
		bg.scaleX = graphicScale;
		bg.scaleY = graphicScale;
		bg.smoothing = ClientPrefs.data.antialiasing;
		addChild(bg);

		y = -height;
		visible = false;

		var backingBar:Bitmap = new Bitmap(Assets.getBitmapData(Paths.getPath('images/soundtray/bars_10.png', IMAGE)));
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
			var bar:Bitmap = new Bitmap(Assets.getBitmapData(Paths.getPath('images/soundtray/bars_' + i + '.png', IMAGE)));
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

		volumeUpSound = Paths.getPath('sounds/soundtray/Volup.ogg', SOUND);
		volumeDownSound = Paths.getPath('sounds/soundtray/Voldown.ogg', SOUND);
		volumeMaxSound = Paths.getPath('sounds/soundtray/VolMAX.ogg', SOUND);

		trace("Custom sound tray initialized!");
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