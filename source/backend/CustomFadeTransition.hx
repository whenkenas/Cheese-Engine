package backend;

import flixel.util.FlxGradient;
#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

class CustomFadeTransition extends MusicBeatSubstate {
	public static var finishCallback:Void->Void;
	var isTransIn:Bool = false;
	var transBlack:FlxSprite;
	var transGradient:FlxSprite;

	var duration:Float;
	
	#if HSCRIPT_ALLOWED
	private static var useCustomScript:Bool = false;
	private static var customScript:HScript = null;
	#end
	
	public function new(duration:Float, isTransIn:Bool)
	{
		#if HSCRIPT_ALLOWED
		if(customScript == null)
			customScript = BackendLoader.getBackendScript('CustomFadeTransition');
		
		if(customScript != null)
		{
			useCustomScript = true;
			this.duration = duration;
			this.isTransIn = isTransIn;
			super();
			
			customScript.set('transition', this);
			customScript.set('duration', duration);
			customScript.set('isTransIn', isTransIn);
			
			if(customScript.exists('new'))
				customScript.call('new', [this, duration, isTransIn]);
			
			return;
		}
		#end
		
		this.duration = duration;
		this.isTransIn = isTransIn;
		super();
	}

	override function create()
	{
		#if HSCRIPT_ALLOWED
		if(useCustomScript && customScript != null && customScript.exists('create'))
		{
			customScript.call('create', [this]);
			super.create();
			return;
		}
		#end
		
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];
		var width:Int = Std.int(FlxG.width / Math.max(camera.zoom, 0.001));
		var height:Int = Std.int(FlxG.height / Math.max(camera.zoom, 0.001));
		transGradient = FlxGradient.createGradientFlxSprite(1, height, (isTransIn ? [0x0, FlxColor.BLACK] : [FlxColor.BLACK, 0x0]));
		transGradient.scale.x = width;
		transGradient.updateHitbox();
		transGradient.scrollFactor.set();
		transGradient.screenCenter(X);
		add(transGradient);

		transBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		transBlack.scale.set(width, height + 400);
		transBlack.updateHitbox();
		transBlack.scrollFactor.set();
		transBlack.screenCenter(X);
		add(transBlack);

		if(isTransIn)
			transGradient.y = transBlack.y - transBlack.height;
		else
			transGradient.y = -transGradient.height;

		super.create();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		#if HSCRIPT_ALLOWED
		if(useCustomScript && customScript != null && customScript.exists('update'))
		{
			customScript.call('update', [elapsed]);
			return;
		}
		#end

		final height:Float = FlxG.height * Math.max(camera.zoom, 0.001);
		final targetPos:Float = transGradient.height + 50 * Math.max(camera.zoom, 0.001);
		if(duration > 0)
			transGradient.y += (height + targetPos) * elapsed / duration;
		else
			transGradient.y = (targetPos) * elapsed;

		if(isTransIn)
			transBlack.y = transGradient.y + transGradient.height;
		else
			transBlack.y = transGradient.y - transBlack.height;

		if(transGradient.y >= targetPos)
		{
			close();
		}
	}

	override function close():Void
	{
		#if HSCRIPT_ALLOWED
		if(useCustomScript && customScript != null && customScript.exists('close'))
		{
			customScript.call('close', []);
		}
		#end
		
		super.close();

		if(finishCallback != null)
		{
			finishCallback();
			finishCallback = null;
		}
	}
}