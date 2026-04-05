package backend.ui;

import backend.ui.PsychUIBox.UIStyleData;
import flixel.util.FlxSpriteUtil;

class PsychUIDropDownMenu extends PsychUIInputText
{
	public static final CLICK_EVENT = "dropdown_click";

	public var list(default, set):Array<String> = [];
	public var button:FlxSprite;
	public var onSelect:Int->String->Void;

	public var selectedIndex(default, set):Int = -1;
	public var selectedLabel(default, set):String = null;

	var _curFilter:Array<String>;
	var _itemWidth:Float = 0;
	public function new(x:Float, y:Float, list:Array<String>, callback:Int->String->Void, ?width:Float = 100)
	{
		super(x, y);
		if(list == null) list = [];

		_itemWidth = width - 2;
		setGraphicSize(width, 20);
		updateHitbox();
		textObj.y += 2;

		var isCheese:Bool = (ClientPrefs.data.uiTheme == 'Cheese');
		var buttonPath:String = isCheese ? 'psych-ui/themes/cheese/dropdown_button' : 'psych-ui/dropdown_button';
		button = new FlxSprite(behindText.width + 1, 0).loadGraphic(Paths.image(buttonPath, 'embed'), true, 20, 20);
		button.animation.add('normal', [0], false);
		button.animation.add('pressed', [1], false);
		button.animation.play('normal', true);
		add(button);

		onSelect = callback;

		onChange = function(old:String, cur:String)
		{
			if(old != cur)
			{
				if(cur.length == 0)
				{
					_curFilter = null;
					showDropDown(true, 0, _curFilter);
				}
				else
				{
					var isNumeric:Bool = ~/^[0-9]+$/.match(cur);
					
					if(isNumeric)
					{
						var searchIndex:Int = Std.parseInt(cur);
						_curFilter = this.list.filter(function(str:String) {
							var index:Int = this.list.indexOf(str);
							return Std.string(index).indexOf(cur) == 0;
						});
					}
					else
					{
						var searchLower:String = cur.toLowerCase();
						_curFilter = this.list.filter(function(str:String) {
							return str.toLowerCase().indexOf(searchLower) != -1;
						});
					}
					
					showDropDown(true, 0, _curFilter);
				}
			}
		}
		unfocus = function()
		{
			showDropDownClickFix();
			showDropDown(false);
		}

		for (option in list)
			addOption(option);

		selectedIndex = 0;
		showDropDown(false);
	}

	override public function setGraphicSize(width:Float = 0, height:Float = 0)
	{
		var isCheese:Bool = (ClientPrefs.data.uiTheme == 'Cheese');
		if(isCheese)
		{
			var w:Int = Std.int(width);
			if(w > 0)
			{
				bg.makeGraphic(w, 20, FlxColor.TRANSPARENT, true);
				FlxSpriteUtil.drawRoundRect(bg, 0, 0, w, 20, 8, 8, FlxColor.TRANSPARENT, {thickness: 2, color: 0xFFE8A800});
				FlxSpriteUtil.drawRoundRect(bg, 2, 2, w - 4, 16, 6, 6, FlxColor.WHITE, {thickness: 0, color: FlxColor.TRANSPARENT});
				bg.updateHitbox();
			}
			behindText.setGraphicSize(width - 2, 18);
			behindText.updateHitbox();
			if(textObj != null && textObj.exists)
			{
				textObj.scale.x = 1;
				textObj.scale.y = 1;
			}
		}
		else
		{
			super.setGraphicSize(width, height);
		}
	}

	override public function updateHitbox()
	{
		if(ClientPrefs.data.uiTheme == 'Cheese')
		{
			bg.updateHitbox();
			behindText.updateHitbox();
			if(textObj != null && textObj.exists)
				textObj.updateHitbox();
			width = bg.width;
			height = bg.height;
		}
		else
		{
			super.updateHitbox();
		}
	}

	function set_selectedIndex(v:Int)
	{
		selectedIndex = v;
		if(selectedIndex < 0 || selectedIndex >= list.length) selectedIndex = -1;

		@:bypassAccessor selectedLabel = list[selectedIndex];
		text = (selectedLabel != null) ? selectedLabel : '';
		return selectedIndex;
	}

	function set_selectedLabel(v:String)
	{
		var id:Int = list.indexOf(v);
		if(id >= 0)
		{
			@:bypassAccessor selectedIndex = id;
			selectedLabel = v;
			text = selectedLabel;
		}
		else
		{
			@:bypassAccessor selectedIndex = -1;
			selectedLabel = null;
			text = '';
		}
		return selectedLabel;
	}

	var _items:Array<PsychUIDropDownItem> = [];
	public var curScroll:Int = 0;
	override function update(elapsed:Float)
	{
		var lastFocus = PsychUIInputText.focusOn;
		super.update(elapsed);
		if(FlxG.mouse.justPressed)
		{
			if(FlxG.mouse.overlaps(button, camera))
			{
				button.animation.play('pressed', true);
				if(lastFocus != this)
					PsychUIInputText.focusOn = this;
				else if(PsychUIInputText.focusOn == this)
					PsychUIInputText.focusOn = null;
			}
		}
		else if(FlxG.mouse.released && button.animation.curAnim != null && button.animation.curAnim.name != 'normal') button.animation.play('normal', true);

		if(lastFocus != PsychUIInputText.focusOn)
		{
			showDropDown(PsychUIInputText.focusOn == this);
		}
		else if(PsychUIInputText.focusOn == this)
		{
			var wheel:Int = FlxG.mouse.wheel;
			if(FlxG.keys.justPressed.UP) wheel++;
			if(FlxG.keys.justPressed.DOWN) wheel--;
			if(wheel != 0) showDropDown(true, curScroll - wheel, _curFilter);
		}
	}

	private function showDropDownClickFix()
	{
		if(FlxG.mouse.justPressed)
		{
			for (item in _items) //extra update to fix a little bug where it wouldnt click on any option if another input text was behind the drop down
				if(item != null && item.active && item.visible)
					item.update(0);
		}
	}

	public function showDropDown(vis:Bool = true, scroll:Int = 0, onlyAllowed:Array<String> = null)
	{
		if(!vis)
		{
			text = selectedLabel;
			_curFilter = null;
		}

		curScroll = Std.int(Math.max(0, Math.min(onlyAllowed != null ? (onlyAllowed.length - 1) : (list.length - 1), scroll)));
		if(vis)
		{
			var n:Int = 0;
			for (item in _items)
			{
				if(onlyAllowed != null)
				{
					if(onlyAllowed.contains(item.label))
					{
						item.active = item.visible = (n >= curScroll);
						n++;
					}
					else item.active = item.visible = false;
				}
				else
				{
					item.active = item.visible = (n >= curScroll);
					n++;
				}
			}

			var txtY:Float = behindText.y + behindText.height + 1;
			for (num => item in _items)
			{
				if(!item.visible) continue;
				item.x = behindText.x;
				item.y = txtY;
				txtY += item.height;
				item.forceNextUpdate = true;
			}
			if(ClientPrefs.data.uiTheme == 'Cheese')
			{
				var totalH:Int = Std.int(txtY - behindText.y + 2);
				var w:Int = Std.int(bg.width);
				bg.makeGraphic(w, totalH, FlxColor.TRANSPARENT, true);
				FlxSpriteUtil.drawRoundRect(bg, 0, 0, w, totalH, 8, 8, FlxColor.TRANSPARENT, {thickness: 2, color: 0xFFE8A800});
				FlxSpriteUtil.drawRoundRect(bg, 2, 2, w - 4, 16, 6, 6, FlxColor.WHITE, {thickness: 0, color: FlxColor.TRANSPARENT});
				bg.scale.set(1, 1);
				bg.updateHitbox();
			}
			else
			{
				bg.scale.y = txtY - behindText.y + 2;
				bg.updateHitbox();
			}
		}
		else
		{
			for (item in _items)
				item.active = item.visible = false;

			if(ClientPrefs.data.uiTheme == 'Cheese')
			{
				var w:Int = Std.int(bg.width);
				bg.makeGraphic(w, 20, FlxColor.TRANSPARENT, true);
				FlxSpriteUtil.drawRoundRect(bg, 0, 0, w, 20, 8, 8, FlxColor.TRANSPARENT, {thickness: 2, color: 0xFFE8A800});
				FlxSpriteUtil.drawRoundRect(bg, 2, 2, w - 4, 16, 6, 6, FlxColor.WHITE, {thickness: 0, color: FlxColor.TRANSPARENT});
				bg.scale.set(1, 1);
				bg.updateHitbox();
			}
			else
			{
				bg.scale.y = 20;
				bg.updateHitbox();
			}
		}
	}

	public var broadcastDropDownEvent:Bool = true;
	public var autoSort:Bool = true;
	function clickedOn(num:Int, label:String)
	{
		selectedIndex = num;
		showDropDown(false);
		if(onSelect != null) onSelect(num, label);
		if(broadcastDropDownEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
	}

	function addOption(option:String)
	{
		@:bypassAccessor list.push(option);
		var curID:Int = list.length - 1;
		var item:PsychUIDropDownItem = cast recycle(PsychUIDropDownItem, () -> new PsychUIDropDownItem(1, 1, this._itemWidth), true);
		item.cameras = cameras;
		item.label = option;
		item.visible = item.active = false;
		item.onClick = function() clickedOn(curID, option);
		item.forceNextUpdate = true;
		_items.push(item);
		insert(1, item);
	}

	function set_list(v:Array<String>)
	{
		var selected:String = selectedLabel;
		showDropDown(false);

		for (item in _items)
			item.kill();

		_items = [];
		list = [];

		var nonEmpty:Array<String> = v.filter(s -> s.length > 0);
		var hasEmpty:Bool = v.contains('');
		var isNumbered:Bool = nonEmpty.length > 0 && ~/^\d+\./.match(nonEmpty[0]);
		if(!isNumbered && autoSort)
			nonEmpty.sort((a, b) -> a.toLowerCase() < b.toLowerCase() ? -1 : 1);
		var sorted:Array<String> = hasEmpty ? [''].concat(nonEmpty) : nonEmpty;

		for (option in sorted)
			addOption(option);

		if(selected != null && selected.length > 0 && list.contains(selected))
			selectedLabel = selected;
		else
			selectedIndex = 0;
		return v;
	}
}

class PsychUIDropDownItem extends FlxSpriteGroup
{
	public var hoverStyle:UIStyleData = {
		bgColor: 0xFF0066FF,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};
	public var normalStyle:UIStyleData = {
		bgColor: FlxColor.WHITE,
		textColor: FlxColor.BLACK,
		bgAlpha: 1
	};

	public var bg:FlxSprite;
	public var text:FlxText;
	public function new(x:Float = 0, y:Float = 0, width:Float = 100)
	{
		super(x, y);

		var isCheese:Bool = (ClientPrefs.data.uiTheme == 'Cheese');
		if(isCheese)
		{
			hoverStyle  = {bgColor: 0xFFFFE270, textColor: 0xFFC78A00, bgAlpha: 1};
			normalStyle = {bgColor: 0xFFFFFFF5, textColor: 0xFF3D2800, bgAlpha: 1};

			bg = new FlxSprite();
			bg.makeGraphic(Std.int(width), 24, 0xFFFFFFF5, true);
			bg.updateHitbox();

			text = new FlxText(6, 0, width - 8, 8);
			text.color = 0xFF3D2800;
		}
		else
		{
			bg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
			bg.setGraphicSize(width, 20);
			bg.updateHitbox();

			text = new FlxText(0, 0, width, 8);
			text.color = FlxColor.BLACK;
		}
		add(bg);
		add(text);
	}

	public var onClick:Void->Void;
	public var forceNextUpdate:Bool = false;
	var _wasHovered:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(FlxG.mouse.justMoved || FlxG.mouse.justPressed || forceNextUpdate)
		{
			var overlapped:Bool = (FlxG.mouse.overlaps(bg, camera));

			var isCheese:Bool = (ClientPrefs.data.uiTheme == 'Cheese');
			if(isCheese)
			{
				if(overlapped != _wasHovered || forceNextUpdate)
				{
					_wasHovered = overlapped;
					var style = overlapped ? hoverStyle : normalStyle;
					bg.color = style.bgColor;
					bg.alpha = style.bgAlpha;
					text.color = style.textColor;
				}
			}
			else
			{
				var style = overlapped ? hoverStyle : normalStyle;
				bg.color = style.bgColor;
				text.color = style.textColor;
				bg.alpha = style.bgAlpha;
			}
			forceNextUpdate = false;

			if(overlapped && FlxG.mouse.justPressed)
				onClick();
		}
		
		text.x = bg.x;
		text.y = bg.y + bg.height/2 - text.height/2;
	}

	public var label(default, set):String;
	function set_label(v:String)
	{
		label = v;
		text.text = v;
		if(ClientPrefs.data.uiTheme == 'Cheese')
		{
			bg.makeGraphic(Std.int(bg.width), Std.int(text.height + 6), 0xFFFFFFF5, true);
			bg.updateHitbox();
		}
		else
		{
			bg.scale.y = text.height + 6;
			bg.updateHitbox();
		}
		return v;
	}
}
