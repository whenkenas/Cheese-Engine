package backend;

import objects.Character.CharacterFile;
import objects.Character.AnimArray;

using StringTools;

class CodenameCharacterCompat
{
	public static function convert(rawXml:String, characterName:String):CharacterFile
	{
		var xml:Xml = Xml.parse(rawXml).firstElement();
		if(xml == null)
			throw new haxe.Exception('Invalid Codename character XML for "$characterName"');

		var sprite:String = xml.exists("sprite") ? xml.get("sprite") : characterName;

		var posX:Float = xml.exists("x") ? Std.parseFloat(xml.get("x")) : 0;
		var posY:Float = xml.exists("y") ? Std.parseFloat(xml.get("y")) : 0;

		var camX:Float = xml.exists("camx") ? Std.parseFloat(xml.get("camx")) : 0;
		var camY:Float = xml.exists("camy") ? Std.parseFloat(xml.get("camy")) : 0;

		var scale:Float = xml.exists("scale") ? Std.parseFloat(xml.get("scale")) : 1;
		var holdTime:Float = xml.exists("holdTime") ? Std.parseFloat(xml.get("holdTime")) : 4;

		var flipX:Bool = xml.exists("flipX") ? (xml.get("flipX") == "true") : false;
		var isPlayer:Bool = xml.exists("isPlayer") ? (xml.get("isPlayer") == "true") : false;

		var antialiasing:Bool = xml.exists("antialiasing") ? (xml.get("antialiasing") == "true") : true;
		var icon:String = xml.exists("icon") ? xml.get("icon") : characterName;

		var healthbarColors:Array<Int> = [161, 161, 161];
		if(xml.exists("color"))
		{
			var col:Int = Std.parseInt('0xFF' + xml.get("color").replace('#', ''));
			healthbarColors = [(col >> 16) & 0xFF, (col >> 8) & 0xFF, col & 0xFF];
		}

		var animations:Array<AnimArray> = [];
		for (node in xml.elementsNamed("anim"))
		{
			var indices:Array<Int> = node.exists("indices") ? parseNumberRange(node.get("indices")) : [];

			animations.push({
				anim: node.exists("anim") ? node.get("anim") : "",
				name: node.exists("name") ? node.get("name") : "",
				fps: node.exists("fps") ? Std.parseInt(node.get("fps")) : 24,
				loop: node.exists("loop") ? (node.get("loop") == "true") : false,
				indices: indices,
				offsets: [
					node.exists("x") ? Std.int(Math.round(Std.parseFloat(node.get("x")))) : 0,
					node.exists("y") ? Std.int(Math.round(Std.parseFloat(node.get("y")))) : 0
				]
			});
		}

		return {
			image: 'characters/$sprite',
			scale: scale,
			sing_duration: holdTime,
			healthicon: icon,
			position: [posX, posY],
			camera_position: [camX, camY],
			flip_x: flipX,
			no_antialiasing: !antialiasing,
			healthbar_colors: healthbarColors,
			vocals_file: '',
			animations: animations,
			_editor_isPlayer: isPlayer
		};
	}

	static function parseNumberRange(str:String):Array<Int>
	{
		var result:Array<Int> = [];
		for (part in str.split(','))
		{
			part = part.trim();
			if(part.length == 0) continue;

			if(part.indexOf('-') > 0)
			{
				var bounds:Array<String> = part.split('-');
				var from:Null<Int> = Std.parseInt(bounds[0]);
				var to:Null<Int> = Std.parseInt(bounds[1]);
				if(from != null && to != null)
					for (i in from...(to + 1))
						result.push(i);
			}
			else
			{
				var val:Null<Int> = Std.parseInt(part);
				if(val != null) result.push(val);
			}
		}
		return result;
	}
}