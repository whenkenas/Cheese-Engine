package backend;

class CodenameEventCompat
{
	public static var charNames:Array<String> = ["dad", "bf", "gf"];

	public static function convert(rawEvents:Array<Dynamic>):Array<Dynamic>
	{
		var sorted:Array<Dynamic> = rawEvents.copy();
		sorted.sort(function(a, b) {
			var timeA:Float = Reflect.field(a, "time");
			var timeB:Float = Reflect.field(b, "time");
			if (timeA < timeB) return -1;
			if (timeA > timeB) return 1;
			return 0;
		});

		var result:Array<Dynamic> = [];

		for (raw in sorted)
		{
			var name:String = Reflect.field(raw, "name");
			var time:Float = Reflect.field(raw, "time");
			var params:Array<Dynamic> = Reflect.field(raw, "params");

			if(name == null) continue;

			var converted:Array<String> = [name];
			if(params != null)
				for (p in params)
					converted.push(Std.string(p));

			pushEvent(result, time, converted);
		}

		return result;
	}

	static function pushEvent(result:Array<Dynamic>, time:Float, converted:Array<String>):Void
	{
		for (entry in result)
		{
			if (entry[0] == time)
			{
				entry[1].push(converted);
				return;
			}
		}
		result.push([time, [converted]]);
	}
}
