package psychlua;

import flixel.tweens.FlxTween;

class HScriptTweenCompat
{
	public static function tween(Object:Dynamic, Values:Dynamic, Duration:Float, ?Options:Dynamic):FlxTween
	{
		if(states.PlayState.instance != null && states.PlayState.instance.skipInstantTweens) Duration = 0.001;
		return FlxTween.tween(Object, Values, Duration, Options);
	}

	public static function color(Object:Dynamic, Duration:Float, FromColor:Dynamic, ToColor:Dynamic, ?Options:Dynamic):FlxTween
	{
		if(states.PlayState.instance != null && states.PlayState.instance.skipInstantTweens) Duration = 0.001;
		return FlxTween.color(Object, Duration, FromColor, ToColor, Options);
	}

	public static function num(FromValue:Float, ToValue:Float, Duration:Float, ?Options:Dynamic, ?TweenFunction:Dynamic->Void):FlxTween
	{
		if(states.PlayState.instance != null && states.PlayState.instance.skipInstantTweens) Duration = 0.001;
		return FlxTween.num(FromValue, ToValue, Duration, Options, TweenFunction);
	}

	public static function angle(Sprite:Dynamic, FromAngle:Float, ToAngle:Float, Duration:Float, ?Options:Dynamic):FlxTween
	{
		if(states.PlayState.instance != null && states.PlayState.instance.skipInstantTweens) Duration = 0.001;
		return FlxTween.angle(Sprite, FromAngle, ToAngle, Duration, Options);
	}

	public static function cancelTweensOf(Object:Dynamic, ?FieldPaths:Array<String>):Void
	{
		FlxTween.cancelTweensOf(Object, FieldPaths);
	}

	public static function completeTweensOf(Object:Dynamic, ?FieldPaths:Array<String>):Void
	{
		FlxTween.completeTweensOf(Object, FieldPaths);
	}
}