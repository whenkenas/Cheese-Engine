package debug;

import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.display.Shape;
import openfl.display.Sprite;
import debug.StatsGraph;
import backend.MemoryUtils;

class FPSCounter extends Sprite
{
	public var currentFPS(default, null):Int;

	@:noCompletion private var times:Array<Float>;

	#if !html5
	private var gcMem:Float = 0.0;
	private var gcMemPeak:Float = 0.0;
	private var taskMem:Float = 0.0;
	private var taskMemPeak:Float = 0.0;
	#end

	private var _isAdvanced:Bool = false;
	public var isAdvanced(get, set):Bool;
	private var color:Int;

	private var background:Shape;
	private var simpleInfo:TextField;
	
	private var advancedFpsGraph:StatsGraph;
	private var advancedGcMemGraph:StatsGraph;
	private var advancedTaskMemGraph:StatsGraph;

	public var bgShape:Shape;
	public var infoDisplay:TextField;
	public var fpsValue:TextField;
	public var fpsLabel:TextField;
	public var memNow:TextField;
	public var memMax:TextField;
	public var coreName:TextField;
	public var buildData:TextField;

	static final UPDATE_DELAY:Int = 100;
	static final INNER_RECT_DIFF:Int = 3;
	static final OUTER_RECT_DIMENSIONS:Array<Int> = [234, 201];
	static final OTHERS_OFFSET:Int = 8;

	var deltaTimeout:Float = 0.0;
	
	public var backgroundOpacity:Float = 0.5;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF)
	{
		super();

		this.x = x;
		this.y = y;
		this.color = color;

		currentFPS = 0;
		times = [];
		this.backgroundOpacity = 0;
		this._isAdvanced = false;
	}

	public function preloadBothModes():Void
	{
		buildDisplay(_isAdvanced);
	}

	private function buildDisplay(advanced:Bool):Void
	{
		removeChildren(0, numChildren);

		final BG_WIDTH_MULTIPLIER:Float = #if html5 advanced ? 1 : 0.3 #else 1 #end;

		#if html5
		final BG_HEIGHT_MULTIPLIER:Float = advanced ? 0.45 : 0.15;
		#else
		final BG_HEIGHT_MULTIPLIER:Float = advanced ? 1 : MemoryUtils.supportsTaskMem() ? 0.3 : 0.2;
		#end

		background = new Shape();
		background.graphics.beginFill(0x3d3f41, 1);
		background.graphics.drawRect(0, 0, (OUTER_RECT_DIMENSIONS[0] * BG_WIDTH_MULTIPLIER) + (INNER_RECT_DIFF * 2),
			(OUTER_RECT_DIMENSIONS[1] * BG_HEIGHT_MULTIPLIER) + (INNER_RECT_DIFF * 2));
		background.graphics.endFill();
		background.graphics.beginFill(0x2c2f30, 1);
		background.graphics.drawRect(INNER_RECT_DIFF, INNER_RECT_DIFF, OUTER_RECT_DIMENSIONS[0] * BG_WIDTH_MULTIPLIER,
			OUTER_RECT_DIMENSIONS[1] * BG_HEIGHT_MULTIPLIER);
		background.graphics.endFill();
		background.alpha = backgroundOpacity;
		addChild(background);
		
		bgShape = background;

		if (advanced)
		{
			createAdvancedElements();
			updateAdvancedDisplay();
		}
		else
		{
			createSimpleElements();
			updateSimpleDisplay();
		}
	}

	private function createSimpleElements():Void
	{
		simpleInfo = new TextField();
		simpleInfo.x = OTHERS_OFFSET;
		simpleInfo.y = OTHERS_OFFSET;
		simpleInfo.width = 500;
		simpleInfo.selectable = false;
		simpleInfo.mouseEnabled = false;
		simpleInfo.defaultTextFormat = new TextFormat('Monsterrat', 12, color, JUSTIFY);
		simpleInfo.antiAliasType = NORMAL;
		simpleInfo.multiline = true;
		addChild(simpleInfo);

		infoDisplay = simpleInfo;
		fpsValue = infoDisplay;
		fpsLabel = infoDisplay;
		memNow = infoDisplay;
		memMax = infoDisplay;
		coreName = infoDisplay;
		buildData = infoDisplay;
	}

	private function createAdvancedElements():Void
	{
		final graphsWidth:Int = OUTER_RECT_DIMENSIONS[0] + (INNER_RECT_DIFF * 2) - (OTHERS_OFFSET * 3);
		final graphsHeight:Int = 25;

		advancedFpsGraph = new StatsGraph(OTHERS_OFFSET, OTHERS_OFFSET + 49, graphsWidth, graphsHeight, 0xFFFFFF);
		advancedFpsGraph.textDisplay.y = -49;
		advancedFpsGraph.minValue = 0;
		addChild(advancedFpsGraph);

		#if !html5
		advancedGcMemGraph = new StatsGraph(OTHERS_OFFSET, Math.floor(OTHERS_OFFSET + (advancedFpsGraph.y + advancedFpsGraph.axisHeight) + 22), graphsWidth, graphsHeight, 0xFFFFFF);
		advancedGcMemGraph.minValue = 0;
		addChild(advancedGcMemGraph);

		if (MemoryUtils.supportsTaskMem())
		{
			advancedTaskMemGraph = new StatsGraph(OTHERS_OFFSET, Math.floor(OTHERS_OFFSET + (advancedGcMemGraph.y + advancedGcMemGraph.axisHeight) + 22), graphsWidth, graphsHeight, 0xFFFFFF);
			advancedTaskMemGraph.minValue = 0;
			addChild(advancedTaskMemGraph);
		}
		#end

		infoDisplay = null;
		fpsValue = null;
		fpsLabel = null;
		memNow = null;
		memMax = null;
		coreName = null;
		buildData = null;
	}

	private override function __enterFrame(deltaTime:Int):Void
	{
		if (!visible) return;

		#if html5
		final currentTime:Float = js.Browser.window.performance.now();
		#else
		final currentTime:Float = haxe.Timer.stamp() * 1000;
		#end

		times.push(currentTime);

		while (times[0] < currentTime - 1000)
		{
			times.shift();
		}

		if (deltaTimeout < UPDATE_DELAY)
		{
			deltaTimeout += deltaTime;
			return;
		}

		currentFPS = times.length;

		#if !html5
		gcMem = MemoryUtils.getGCMemory();
		if (gcMem > gcMemPeak) gcMemPeak = gcMem;

		if (MemoryUtils.supportsTaskMem())
		{
			taskMem = MemoryUtils.getTaskMemory();
			if (taskMem > taskMemPeak) taskMemPeak = taskMem;
		}
		#end

		if (_isAdvanced)
		{
			updateAdvancedDisplay();
		}
		else
		{
			updateSimpleDisplay();
		}

		deltaTimeout = 0.0;
	}

	private function updateAdvancedDisplay():Void
	{
		if (advancedFpsGraph != null)
		{
			advancedFpsGraph.maxValue = FlxG.drawFramerate;
			advancedFpsGraph.update(times.length);

			final info:Array<String> = [];
			info.push('FPS: $currentFPS');
			info.push('AVG FPS: ${Math.floor(advancedFpsGraph.average())}');
			info.push('1% LOW FPS: ${Math.floor(advancedFpsGraph.lowest())}');
			advancedFpsGraph.textDisplay.text = info.join('\n');
		}

		#if !html5
		if (advancedGcMemGraph != null)
		{
			advancedGcMemGraph.maxValue = gcMemPeak;
			advancedGcMemGraph.update(gcMem);
			advancedGcMemGraph.textDisplay.text = 'GC MEM: ${flixel.util.FlxStringUtil.formatBytes(gcMem).toLowerCase()} / ${flixel.util.FlxStringUtil.formatBytes(gcMemPeak).toLowerCase()}';
		}

		if (advancedTaskMemGraph != null)
		{
			advancedTaskMemGraph.maxValue = taskMemPeak;
			advancedTaskMemGraph.update(taskMem);
			advancedTaskMemGraph.textDisplay.text = 'TASK MEM: ${flixel.util.FlxStringUtil.formatBytes(taskMem).toLowerCase()} / ${flixel.util.FlxStringUtil.formatBytes(taskMemPeak).toLowerCase()}';
		}
		#end
	}

	private function updateSimpleDisplay():Void
	{
		if (infoDisplay != null)
		{
			final info:Array<String> = [];
			info.push('FPS: $currentFPS');

			#if !html5
			info.push('GC MEM: ${flixel.util.FlxStringUtil.formatBytes(gcMem).toLowerCase()} / ${flixel.util.FlxStringUtil.formatBytes(gcMemPeak).toLowerCase()}');

			if (MemoryUtils.supportsTaskMem())
				info.push('TASK MEM: ${flixel.util.FlxStringUtil.formatBytes(taskMem).toLowerCase()} / ${flixel.util.FlxStringUtil.formatBytes(taskMemPeak).toLowerCase()}');
			#end

			infoDisplay.text = info.join('\n');
		}
	}

	public dynamic function updateText():Void
	{
		if (_isAdvanced)
		{
			updateAdvancedDisplay();
		}
		else
		{
			updateSimpleDisplay();
		}
	}

	public function setBackgroundOpacity(opacity:Float):Void
	{
		backgroundOpacity = opacity;
		if (background != null) background.alpha = opacity;
	}

	function get_isAdvanced():Bool
	{
		return _isAdvanced;
	}

	function set_isAdvanced(value:Bool):Bool
	{
		buildDisplay(value);

		return _isAdvanced = value;
	}
}
