package objects;

import flixel.addons.display.FlxPieDial;

#if hxvlc
import hxvlc.flixel.FlxVideoSprite;
#end

class VideoSprite extends FlxSpriteGroup {
	#if VIDEOS_ALLOWED
	public var finishCallback:Void->Void = null;
	public var onSkip:Void->Void = null;

	final _timeToSkip:Float = 1;
	public var holdingTime:Float = 0;
	public var videoSprite:FlxVideoSprite;
	public var skipSprite:FlxPieDial;
	public var cover:FlxSprite;
	public var canSkip(default, set):Bool = false;

	private var videoName:String;

	public var waiting:Bool = false;
	#if VIDEOS_ALLOWED
	public static var precachedVideos:Map<String, VideoSprite> = new Map();
	#end

	public function new(videoName:String, isWaiting:Bool, canSkip:Bool = false, shouldLoop:Dynamic = false) {
		super();

		this.videoName = videoName;
		scrollFactor.set();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		waiting = isWaiting;
		if(!waiting)
		{
			cover = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
			cover.scale.set(FlxG.width + 100, FlxG.height + 100);
			cover.screenCenter();
			cover.scrollFactor.set();
			add(cover);
		}

		// initialize sprites
		videoSprite = new FlxVideoSprite();
		videoSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(videoSprite);
		if(canSkip) this.canSkip = true;

		// callbacks
		if(!shouldLoop) videoSprite.bitmap.onEndReached.add(finishVideo);

		videoSprite.bitmap.onFormatSetup.add(function()
		{
			#if hxvlc
			var bd = videoSprite.bitmap.bitmapData;
			var wd:Int = (bd != null) ? bd.width : 0;
			var hg:Int = (bd != null) ? bd.height : 0;
			if(wd > 0 && hg > 0)
			{
				var scaleX:Float = FlxG.width / wd;
				var scaleY:Float = FlxG.height / hg;
				videoSprite.scale.set(scaleX, scaleY);
				videoSprite.updateHitbox();
			}
			else
			{
				videoSprite.setGraphicSize(FlxG.width, FlxG.height);
				videoSprite.updateHitbox();
			}
			#else
			videoSprite.setGraphicSize(FlxG.width);
			videoSprite.updateHitbox();
			#end
			videoSprite.screenCenter();
		});

		var vlcOptions:Array<String> = [
			'avcodec-hw=any',
			'avcodec-fast',
			'avcodec-skiploopfilter=0',
			'avcodec-skip-frame=0',
			'avcodec-skip-idct=0',
			'sout-transcode-high-quality',
			'no-drop-late-frames',
			'no-skip-frames'
		];
		if(shouldLoop) vlcOptions.push('input-repeat=65545');
		if(waiting)
			videoSprite.bitmap.load(videoName, vlcOptions);
		else
			videoSprite.load(videoName, vlcOptions);
	}

	var alreadyDestroyed:Bool = false;
	override function destroy()
	{
		if(alreadyDestroyed)
			return;

		trace('Video destroyed');
		if(cover != null)
		{
			remove(cover);
			cover.destroy();
		}
		
		finishCallback = null;
		onSkip = null;

		if(FlxG.state != null)
		{
			if(FlxG.state.members.contains(this))
				FlxG.state.remove(this);

			if(FlxG.state.subState != null && FlxG.state.subState.members.contains(this))
				FlxG.state.subState.remove(this);
		}
		super.destroy();
		alreadyDestroyed = true;
	}
	function finishVideo()
	{
		if (!alreadyDestroyed)
		{
			if(finishCallback != null)
				finishCallback();
			
			destroy();
		}
	}

	override function set_alpha(value:Float):Float
	{
		super.set_alpha(value);
		if(videoSprite != null) videoSprite.alpha = value;
		if(cover != null) cover.alpha = value;
		return alpha;
	}

	override function set_x(value:Float):Float
	{
		super.set_x(value);
		if(videoSprite != null) videoSprite.x = value;
		return x;
	}

	override function set_y(value:Float):Float
	{
		super.set_y(value);
		if(videoSprite != null) videoSprite.y = value;
		return y;
	}

	override function set_angle(value:Float):Float
	{
		super.set_angle(value);
		if(videoSprite != null) videoSprite.angle = value;
		return angle;
	}

	override function update(elapsed:Float)
	{
		if(canSkip)
		{
			var isHolding:Bool = Controls.instance.pressed('accept')
				|| FlxG.keys.pressed.ENTER
				|| FlxG.keys.pressed.SPACE;
			if(isHolding)
			{
				holdingTime = Math.max(0, Math.min(_timeToSkip, holdingTime + elapsed));
			}
			else if (holdingTime > 0)
			{
				holdingTime = Math.max(0, FlxMath.lerp(holdingTime, -0.1, FlxMath.bound(elapsed * 3, 0, 1)));
			}
			updateSkipAlpha();

			if(holdingTime >= _timeToSkip)
			{
				if(onSkip != null) onSkip();
				trace('Skipped video');
				var cb = finishCallback;
				finishCallback = null;
				if(cb != null) cb();
				destroy();
				return;
			}
		}
		super.update(elapsed);
	}

	function set_canSkip(newValue:Bool)
	{
		canSkip = newValue;
		if(canSkip)
		{
			if(skipSprite == null)
			{
				skipSprite = new FlxPieDial(0, 0, 40, FlxColor.WHITE, 40, true, 24);
				skipSprite.replaceColor(FlxColor.BLACK, FlxColor.TRANSPARENT);
				skipSprite.x = FlxG.width - (skipSprite.width + 80);
				skipSprite.y = FlxG.height - (skipSprite.height + 72);
				skipSprite.amount = 0;
				add(skipSprite);
			}
		}
		else if(skipSprite != null)
		{
			remove(skipSprite);
			skipSprite.destroy();
			skipSprite = null;
		}
		return canSkip;
	}

	function updateSkipAlpha()
	{
		if(skipSprite == null) return;

		skipSprite.amount = Math.min(1, Math.max(0, (holdingTime / _timeToSkip) * 1.025));
		skipSprite.alpha = FlxMath.remapToRange(skipSprite.amount, 0.025, 1, 0, 1);
	}

	public function play() videoSprite?.play();
	public function resume() videoSprite?.resume();
	public function pause() videoSprite?.pause();
	
	public function setTime(time:Float)
	{
		if(videoSprite != null && videoSprite.bitmap != null)
		{
			var videoTime:Int = Std.int(time);
			var videoDuration:Int = haxe.Int64.toInt(videoSprite.bitmap.duration);
			if(videoTime >= 0 && videoTime < videoDuration)
				videoSprite.bitmap.time = videoTime;
		}
	}
	
	public function getTime():Float
	{
		if(videoSprite != null && videoSprite.bitmap != null)
			return haxe.Int64.toInt(videoSprite.bitmap.time);
		return 0;
	}
	
	public function getDuration():Float
	{
		if(videoSprite != null && videoSprite.bitmap != null)
			return haxe.Int64.toInt(videoSprite.bitmap.duration);
		return 0;
	}
	#end
}