package backend;

import openfl.display.BitmapData;

@:bitmap("assets/embed/images/ui/cursor.png")
private class FunkinCursor extends BitmapData {}

@:bitmap("assets/embed/images/ui/cursor-pointer.png")
class PointerCursor extends BitmapData {}

@:bitmap("assets/embed/images/ui/cursor-grabbing.png")
class GrabbingCursor extends BitmapData {}

@:bitmap("assets/embed/images/ui/cursor-cell.png")
class CellCursor extends BitmapData {}

class CursorLoader
{
	static var _lastMod:String = null;
	static var _lastData:BitmapData = null;

	public static function load():Void
	{
		#if MODS_ALLOWED
		var curMod:String = Mods.currentModDirectory;
		if (curMod == _lastMod && FlxG.mouse.cursor != null)
			return;

		_lastMod = curMod;

		var modPath:String = Paths.mods(curMod + '/images/ui/cursor.png');
		if (sys.FileSystem.exists(modPath))
		{
			_lastData = BitmapData.fromFile(modPath);
			FlxG.mouse.load(_lastData);
			return;
		}

		for (mod in Mods.getGlobalMods())
		{
			var globalPath:String = Paths.mods(mod + '/images/ui/cursor.png');
			if (sys.FileSystem.exists(globalPath))
			{
				_lastData = BitmapData.fromFile(globalPath);
				FlxG.mouse.load(_lastData);
				return;
			}
		}
		#end

		if (!(FlxG.mouse.cursor?.bitmapData is FunkinCursor))
			FlxG.mouse.load(new FunkinCursor(0, 0));
	}

	public static function reset():Void
	{
		_lastMod = null;
		_lastData = null;
	}
}