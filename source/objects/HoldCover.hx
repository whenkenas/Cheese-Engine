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
			animation.addByPrefix('hold', 'holdCoverRGB', 24, true);
			animation.addByPrefix('end', 'holdCoverEndRGB', 24, false);
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
				animation.addByPrefix('hold', 'holdCoverRGB', 33, true);
				animation.addByPrefix('end', 'holdCoverEndRGB', 33, false);
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
		
		var offsetX:Float = -105;
		var offsetY:Float = -100;
		
		if(isPixelStage)
		{
			offsetX = -385;
			offsetY = -125;
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
}