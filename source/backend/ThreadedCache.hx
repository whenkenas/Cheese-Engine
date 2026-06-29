package backend;

import openfl.display.BitmapData;
import flixel.graphics.FlxGraphic;
import flash.media.Sound;

#if sys
import sys.thread.Thread;
import sys.thread.Mutex;
#end

@:access(openfl.display.BitmapData)
class ThreadedCache
{
	#if sys
	static var mutex:Mutex = new Mutex();
	static var pendingBitmaps:Array<{key:String, bitmap:BitmapData, allowGPU:Bool}> = [];
	static var pendingSounds:Array<{file:String, sound:Sound}> = [];

	public static function loadBitmapAsync(key:String, file:String, ?allowGPU:Bool = true):Void
	{
		Thread.create(() -> {
			var bitmap:BitmapData = null;
			#if MODS_ALLOWED
			if (FileSystem.exists(file))
				bitmap = BitmapData.fromFile(file);
			else
			#end
			if (openfl.utils.Assets.exists(file, IMAGE))
				bitmap = openfl.utils.Assets.getBitmapData(file);

			if (bitmap != null)
			{
				mutex.acquire();
				pendingBitmaps.push({key: key, bitmap: bitmap, allowGPU: allowGPU});
				mutex.release();
			}
		});
	}

	public static function loadSoundAsync(file:String):Void
	{
		Thread.create(() -> {
			var sound:Sound = null;
			#if sys
			if (FileSystem.exists(file))
				sound = Sound.fromFile(file);
			#end
			if (sound == null && openfl.utils.Assets.exists(file, SOUND))
				sound = openfl.utils.Assets.getSound(file);

			if (sound != null)
			{
				mutex.acquire();
				pendingSounds.push({file: file, sound: sound});
				mutex.release();
			}
		});
	}

	public static function processPending():Void
	{
		mutex.acquire();
		var bitmaps = pendingBitmaps.splice(0, pendingBitmaps.length);
		var sounds = pendingSounds.splice(0, pendingSounds.length);
		mutex.release();

		for (entry in bitmaps)
		{
			if (!Paths.currentTrackedAssets.exists(entry.key))
				Paths.cacheBitmap(entry.key, null, entry.bitmap, entry.allowGPU);
		}

		for (entry in sounds)
		{
			if (!Paths.currentTrackedSounds.exists(entry.file))
			{
				Paths.currentTrackedSounds.set(entry.file, entry.sound);
				Paths.localTrackedAssets.push(entry.file);
			}
		}
	}
	#end
}