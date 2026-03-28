package objects;

import flixel.FlxSprite;
import flixel.FlxCamera;
import backend.ClientPrefs;
import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;

class HoldCover extends FlxSprite
{
	public var noteData:Int = 0;
	public var isOpponent:Bool = false;
	public var colorName:String = '';
	public var rgbShader:RGBShaderReference;
	public var disabled:Bool = false;
	public var invisible:Bool = false;
	public var forceHide:Bool = false;

	public var configOffsetNormal:Array<Float> = [-105, -100];
	public var configOffsetPixel:Array<Float> = [-385, -125];
	public var configAnimPrefixes:Map<String, String> = new Map();
	public var configAnimFps:Map<String, Array<Int>> = new Map();
	public var configAnimLoop:Map<String, Bool> = new Map();
	public var configAnimOffsets:Map<String, Array<Float>> = new Map();
	
	private static var colors:Array<String> = ['Purple', 'Blue', 'Green', 'Red'];
	
	public function new(noteData:Int, isOpponent:Bool, isPixelStage:Bool, camera:FlxCamera)
	{
		super();
		
		this.noteData = noteData;
		this.isOpponent = isOpponent;
		this.colorName = colors[noteData];
		
		var customSkin:String = PlayState.SONG != null ? PlayState.SONG.holdCoverSkin : null;
		var path:String = isPixelStage ? 'holdCovers/holdCoverPixelRGB' : 'holdCovers/holdCoverRGB';
		if(customSkin != null && customSkin.trim().length > 0 && Paths.fileExists('images/$customSkin.png', IMAGE))
			path = customSkin;

		var usePixelCover:Bool = isPixelStage && (customSkin == null || customSkin.trim().length == 0) && Paths.fileExists('images/pixelUI/pixelNoteHoldCover.png', IMAGE);
		if(usePixelCover)
		{
			frames = Paths.getSparrowAtlas('pixelUI/pixelNoteHoldCover');
			animation.addByPrefix('hold', 'loop', 24, true);
			animation.addByPrefix('end', 'explode', 24, false);
		}
		else
		{
			frames = Paths.getSparrowAtlas(path);
			loadCoverConfig(path);
			var holdPrefix = configAnimPrefixes.exists('hold_$noteData') ? configAnimPrefixes.get('hold_$noteData') : 'holdCoverRGB';
			var endPrefix = configAnimPrefixes.exists('end_$noteData') ? configAnimPrefixes.get('end_$noteData') : 'holdCoverEndRGB';
			var holdFps = configAnimFps.exists('hold_$noteData') ? configAnimFps.get('hold_$noteData')[1] : 24;
			var endFps = configAnimFps.exists('end_$noteData') ? configAnimFps.get('end_$noteData')[1] : 24;
			var holdLoop = configAnimLoop.exists('hold_$noteData') ? configAnimLoop.get('hold_$noteData') : true;
			var endLoop = configAnimLoop.exists('end_$noteData') ? configAnimLoop.get('end_$noteData') : false;
			animation.addByPrefix('hold', holdPrefix, holdFps, holdLoop);
			animation.addByPrefix('end', endPrefix, endFps, endLoop);
		}
		
		visible = false;
		cameras = [camera];
		
		if(isPixelStage)
		{
			setGraphicSize(Std.int(width * 6));
			updateHitbox();
			if(usePixelCover)
			{
				animation.addByPrefix('hold', 'loop', 24, true);
				animation.addByPrefix('end', 'explode', 16, false);
			}
			else
			{
				var holdPrefix = configAnimPrefixes.exists('hold_$noteData') ? configAnimPrefixes.get('hold_$noteData') : 'holdCoverRGB';
				var endPrefix = configAnimPrefixes.exists('end_$noteData') ? configAnimPrefixes.get('end_$noteData') : 'holdCoverEndRGB';
				var holdFps = configAnimFps.exists('hold_$noteData') ? configAnimFps.get('hold_$noteData')[1] : 33;
				var endFps = configAnimFps.exists('end_$noteData') ? configAnimFps.get('end_$noteData')[1] : 33;
				var holdLoop = configAnimLoop.exists('hold_$noteData') ? configAnimLoop.get('hold_$noteData') : true;
				var endLoop = configAnimLoop.exists('end_$noteData') ? configAnimLoop.get('end_$noteData') : false;
				animation.addByPrefix('hold', holdPrefix, holdFps, holdLoop);
				animation.addByPrefix('end', endPrefix, endFps, endLoop);
			}
			antialiasing = false;
		}
		else
		{
			antialiasing = ClientPrefs.data.antialiasing;
		}
		
		alpha = ClientPrefs.data.holdCoverAlpha;
	}
	
	public function playHold():Void
	{
		if(animation.curAnim == null || animation.curAnim.name != 'hold')
		{
			animation.play('hold', false);
		}
	}
	
	public function playEnd():Void
	{
		if(animation.curAnim == null || animation.curAnim.name != 'end')
		{
			animation.play('end', true);
		}
	}
	
	public function hide():Void
	{
		if(visible && animation.curAnim != null)
		{
			if(animation.curAnim.name == 'hold')
				animation.play('end', true);
			else if(animation.curAnim.name != 'end')
				visible = false;
		}
		else
		{
			visible = false;
		}
	}
	
	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		
		if(visible && animation.curAnim != null)
		{
			if(animation.curAnim.name == 'end' && animation.curAnim.finished)
				visible = false;
			else if(animation.curAnim.name == 'hold' && animation.curAnim.finished)
				animation.play('hold', true);
		}
	}
	
	public function updatePosition(strum:StrumNote, isPixelStage:Bool):Void
	{
		if(disabled || invisible || forceHide)
		{
			visible = false;
			return;
		}
		if(ClientPrefs.data.holdCoverAlpha <= 0)
		{
			visible = false;
			return;
		}
		if(strum == null)
		{
			visible = false;
			return;
		}
		
		if(!strum.visible || strum.alpha <= 0)
		{
			visible = false;
			return;
		}
		
		visible = true;
		angle = strum.angle;
		
		var offsetX:Float = isPixelStage ? configOffsetPixel[0] : configOffsetNormal[0];
		var offsetY:Float = isPixelStage ? configOffsetPixel[1] : configOffsetNormal[1];

		if(animation.curAnim != null)
		{
			var animKey:String = animation.curAnim.name + '_' + noteData;
			if(configAnimOffsets.exists(animKey))
			{
				offsetX = configAnimOffsets.get(animKey)[0];
				offsetY = configAnimOffsets.get(animKey)[1];
			}
		}
		
		setPosition(strum.x + offsetX, strum.y + offsetY);
		
		var finalAlpha:Float = strum.alpha * ClientPrefs.data.holdCoverAlpha;
		if(finalAlpha <= 0.01)
		{
			visible = false;
			return;
		}
		
		alpha = finalAlpha;
	}
	
	public static function getColorName(noteData:Int):String
	{
		return colors[noteData];
	}

	private function loadCoverConfig(path:String):Void
	{
		var jsonPath:String = Paths.getPath('images/$path.json', TEXT);
		if(!Paths.fileExists('images/$path.json', TEXT)) return;

		try
		{
			var raw:Dynamic = haxe.Json.parse(sys.io.File.getContent(jsonPath));

			if(raw.offsetNormal != null)
				configOffsetNormal = raw.offsetNormal;
			if(raw.offsetPixel != null)
				configOffsetPixel = raw.offsetPixel;

			if(raw.animations != null)
			{
				for(k in Reflect.fields(raw.animations))
				{
					var a:Dynamic = Reflect.field(raw.animations, k);
					if(a.prefix != null) configAnimPrefixes.set(k, a.prefix);
					if(a.fps != null) configAnimFps.set(k, a.fps);
					if(a.loop != null) configAnimLoop.set(k, a.loop);
					if(a.offsets != null) configAnimOffsets.set(k, a.offsets);
				}
			}
		}
		catch(e:Dynamic)
		{
			trace('HoldCover: Failed to load config for $path: $e');
		}
	}
}
