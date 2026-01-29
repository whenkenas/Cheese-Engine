package states.editors.content;

import flixel.FlxSprite;
import flixel.util.FlxTimer;
import objects.Character;

class Toy extends Character
{
	var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
	public var isDragging:Bool = false;
	private var dragOffsetX:Float = 0;
	private var dragOffsetY:Float = 0;
	public var baseX:Float = 0;
	public var baseY:Float = 0;
	private var animHoldTimer:Float = 0;
	private var currentAnim:String = '';
	public var toyName:String = '';
	
	public function new(x:Float, y:Float, character:String, isPlayer:Bool = false, name:String = '')
	{
		super(x, y, character, isPlayer);
		
		baseX = x;
		baseY = y;
		toyName = name;
		
		setGraphicSize(Std.int(width * 0.35));
		updateHitbox();
		scrollFactor.set();
		
		this.width = frameWidth * 0.35;
		this.height = frameHeight * 0.35;
		centerOffsets();
		
		dance();
	}
	
	public function performPose(direction:String, sustainLength:Float = 0, noteColor:FlxColor = FlxColor.WHITE)
	{
		var animName:String = direction.toLowerCase();
		
		if(!animOffsets.exists(animName))
			animName = 'sing$direction';
		
		currentAnim = animName;
		
		var baseHoldTime:Float = Conductor.stepCrochet * 4 / 1000;
		var sustainTime:Float = sustainLength / 1000;
		
		animHoldTimer = Math.max(baseHoldTime, sustainTime + baseHoldTime);
		
		super.playAnim(animName, true);
		
		this.color = noteColor;
		
		x = baseX;
		y = baseY;
	}
	
	override public function update(elapsed:Float):Void
	{
		if(animHoldTimer > 0)
		{
			animHoldTimer -= elapsed;
			if(animHoldTimer <= 0)
			{
				animHoldTimer = 0;
				currentAnim = '';
				this.color = FlxColor.WHITE;
				dance();
				x = baseX;
				y = baseY;
			}
		}
		else if(animation.curAnim != null && animation.curAnim.finished && animHoldTimer <= 0)
		{
			this.color = FlxColor.WHITE;
			dance();
			x = baseX;
			y = baseY;
		}
		
		var mouseOverlap:Bool = FlxG.mouse.overlaps(this);
		
		if(mouseOverlap && FlxG.mouse.justPressed && !isDragging)
		{
			isDragging = true;
			dragOffsetX = FlxG.mouse.screenX - baseX;
			dragOffsetY = FlxG.mouse.screenY - baseY;
			alpha = 0.6;
		}
		
		if(isDragging)
		{
			baseX = FlxG.mouse.screenX - dragOffsetX;
			baseY = FlxG.mouse.screenY - dragOffsetY;
			x = baseX;
			y = baseY;
			
			if(FlxG.mouse.justReleased)
			{
				isDragging = false;
				alpha = 1.0;
				
				@:privateAccess
				if(states.editors.ChartingState.instance != null)
					states.editors.ChartingState.instance.saveToyPosition(toyName, baseX, baseY);
			}
		}
		
		if(animation.curAnim != null)
			animation.curAnim.update(elapsed);
	}
	
	override public function dance():Void
	{
		if(isDragging || animHoldTimer > 0)
			return;
			
		super.dance();
		x = baseX;
		y = baseY;
	}
}