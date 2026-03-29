package backend.ui;

import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;
import flixel.util.FlxSpriteUtil;

class PsychUITab extends FlxSprite
{
	public var name(default, set):String;
	public var text:FlxText;
	public var menu:FlxSpriteGroup = new FlxSpriteGroup();

	public var animationDuration:Float = 0.25;
	private var _targetAlpha:Float = 1;
	private var _currentAlpha:Float = 1;
	private var _animating:Bool = false;

	public function new(name:String)
	{
		super();
		if(ClientPrefs.data.uiTheme == 'Cheese')
		{
			makeGraphic(1, 1, FlxColor.TRANSPARENT);
			alpha = 1.0;
		}
		else
		{
			makeGraphic(1, 1, FlxColor.WHITE);
			color = FlxColor.BLACK;
			alpha = 0.6;
		}

		@:bypassAccessor this.name = name;
		text = new FlxText(0, 0, 100, name);
		text.alignment = CENTER;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(_animating)
		{
			_currentAlpha = FlxMath.lerp(_currentAlpha, _targetAlpha, elapsed * (1 / animationDuration) * 10);
			if(Math.abs(_currentAlpha - _targetAlpha) < 0.01)
			{
				_currentAlpha = _targetAlpha;
				_animating = false;
			}
			
			if(text != null)
				text.alpha = _currentAlpha;
			
			if(menu != null)
				menu.alpha = _currentAlpha;
		}
	}

	override function draw()
	{
		super.draw();

		if(visible && text != null && text.exists && text.visible)
		{
			text.x = x;
			text.y = y + height/2 - text.height/2;
			text.draw();
		}
	}

	override function destroy()
	{
		text = FlxDestroyUtil.destroy(text);
		menu = FlxDestroyUtil.destroy(menu);
		super.destroy();
	}
	
	public function updateMenu(parent:PsychUIBox, elapsed:Float)
	{
		if(menu != null && menu.exists && menu.active)
		{
			menu.scrollFactor.set(parent.scrollFactor.x, parent.scrollFactor.y);
			menu.update(elapsed);
		}
	}

	public var menuOffsetX:Float = 0;
	
	public function drawMenu(parent:PsychUIBox)
	{
		if(menu != null && menu.exists && menu.visible)
		{
			var isCheese:Bool = (ClientPrefs.data.uiTheme == 'Cheese');
			menu.x = parent.x + menuOffsetX;
			menu.y = parent.y + parent.tabHeight + (isCheese ? 6 : 0);
			menu.draw();
		}
	}

	public function resize(width:Int, height:Int)
	{
		if(ClientPrefs.data.uiTheme == 'Cheese')
		{
			_redrawTab(width, height, _isSelected);
		}
		else
		{
			setGraphicSize(width, height);
			updateHitbox();
		}
		text.fieldWidth = width;
	}

	public var _isSelected:Bool = false;
	public function _redrawTab(width:Int, height:Int, selected:Bool)
	{
		_isSelected = selected;
		makeGraphic(width, height + 6, FlxColor.TRANSPARENT, true);
		if(selected)
		{
			FlxSpriteUtil.drawRoundRect(this, 0, 0, width, height + 6, 14, 14, 0xFFFFFBEA, {thickness: 2, color: 0xFFE8A800});
			FlxSpriteUtil.drawRect(this, 2, height - 2, width - 4, 8, 0xFFFFFBEA);
		}
		else
		{
			FlxSpriteUtil.drawRoundRect(this, 0, 0, width, height + 6, 14, 14, 0xFFF5C842, {thickness: 2, color: 0xFFE8A800});
			FlxSpriteUtil.drawRect(this, 2, height - 2, width - 4, 8, 0xFFF5C842);
		}
		updateHitbox();
		text.fieldWidth = width;
	}

	function set_name(v:String)
	{
		text.text = v;
		return (name = v);
	}

	override function set_cameras(v:Array<FlxCamera>)
	{
		text.cameras = v;
		menu.cameras = v;
		return super.set_cameras(v);
	}

	override function set_camera(v:FlxCamera)
	{
		text.camera = v;
		menu.camera = v;
		return super.set_camera(v);
	}

	override function set_visible(v:Bool)
	{
		if(v && !visible)
		{
			_currentAlpha = 0;
			_targetAlpha = 1;
			_animating = true;
		}
		else if(!v && visible)
		{
			_targetAlpha = 0;
			_animating = true;
		}
		return super.set_visible(v);
	}
}
