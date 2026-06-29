package backend.ui;

import flixel.util.FlxSpriteUtil;

class AnimScrollList extends FlxSpriteGroup
{
	public static final SELECT_EVENT:String = 'animlist_select';

	public var onSelect:Int->Void;

	public var listWidth(default, null):Int;
	public var listHeight(default, null):Int;

	static inline final ROW_H:Int = 18;
	static inline final TITLE_H:Int = 20;
	static inline final PAD:Int = 6;
	static inline final SBAR_W:Int = 7;

	var _bg:FlxSprite;
	var _titleBg:FlxSprite;
	var _titleTxt:FlxText;
	var _rowBgs:Array<FlxSprite> = [];
	var _rowTxts:Array<FlxText> = [];
	var _sbarTrack:FlxSprite;
	var _sbarThumb:FlxSprite;

	var _anims:Array<Dynamic> = [];
	var _curAnim:Int = 0;
	var _scrollY:Int = 0;
	var _visibleRows:Int = 0;
	var _hoverRow:Int = -1;

	public function new(x:Float, y:Float, width:Int = 210, height:Int = 170)
	{
		super(x, y);
		listWidth = width;
		listHeight = height;
		_visibleRows = Std.int((listHeight - TITLE_H) / ROW_H);

		var isCheese:Bool = (ClientPrefs.data.uiTheme == 'Cheese');

		_bg = new FlxSprite();
		add(_bg);

		_titleBg = new FlxSprite();
		add(_titleBg);

		_titleTxt = new FlxText(0, 3, listWidth, 'Animations');
		_titleTxt.setFormat(null, 12,
			isCheese ? 0xFF7A3D00 : FlxColor.WHITE,
			CENTER,
			isCheese ? NONE : OUTLINE_FAST,
			FlxColor.BLACK);
		_titleTxt.borderSize = 1;
		_titleTxt.antialiasing = true;
		add(_titleTxt);

		var innerW:Int = listWidth - SBAR_W - 1;
		for (i in 0..._visibleRows)
		{
			var rowY:Int = TITLE_H + i * ROW_H;

			var rb:FlxSprite = new FlxSprite(0, rowY).makeGraphic(innerW, ROW_H, FlxColor.WHITE);
			rb.alpha = 0;
			add(rb);
			_rowBgs.push(rb);

			var rt:FlxText = new FlxText(PAD, rowY + 2, innerW - PAD * 2, '');
			rt.setFormat(null, 10,
				isCheese ? 0xFF7A3D00 : FlxColor.WHITE,
				LEFT,
				isCheese ? NONE : OUTLINE_FAST,
				FlxColor.BLACK);
			rt.borderSize = 1;
			rt.antialiasing = true;
			add(rt);
			_rowTxts.push(rt);
		}

		_sbarTrack = new FlxSprite(listWidth - SBAR_W, TITLE_H).makeGraphic(SBAR_W, listHeight - TITLE_H, FlxColor.WHITE);
		_sbarTrack.color = isCheese ? 0xFFD47A00 : FlxColor.BLACK;
		_sbarTrack.alpha = isCheese ? 0.3 : 0.25;
		add(_sbarTrack);

		_sbarThumb = new FlxSprite(listWidth - SBAR_W, TITLE_H).makeGraphic(SBAR_W, listHeight - TITLE_H, FlxColor.WHITE);
		_sbarThumb.color = isCheese ? 0xFFD47A00 : FlxColor.WHITE;
		_sbarThumb.alpha = 0.8;
		_sbarThumb.origin.set(0, 0);
		_sbarThumb.visible = false;
		add(_sbarThumb);

		_redrawBg();
		_redrawTitleBg();
		_refresh();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!FlxG.mouse.overlaps(_bg, camera))
		{
			if (_hoverRow != -1)
			{
				_hoverRow = -1;
				_refresh();
			}
			return;
		}

		if (FlxG.mouse.wheel != 0)
		{
			_scrollY -= FlxG.mouse.wheel;
			@:privateAccess FlxG.mouse.wheel = 0;
			_clamp();
			_refresh();
		}

		var newHover:Int = -1;
		for (i in 0..._rowBgs.length)
		{
			var idx:Int = _scrollY + i;
			if (idx < _anims.length && FlxG.mouse.overlaps(_rowBgs[i], camera))
			{
				newHover = i;
				break;
			}
		}
		if (newHover != _hoverRow)
		{
			_hoverRow = newHover;
			_refresh();
		}

		if (FlxG.mouse.justPressed)
		{
			for (i in 0..._rowBgs.length)
			{
				var idx:Int = _scrollY + i;
				if (idx < _anims.length && FlxG.mouse.overlaps(_rowBgs[i], camera))
				{
					_curAnim = idx;
					_refresh();
					if (onSelect != null) onSelect(_curAnim);
					PsychUIEventHandler.event(SELECT_EVENT, this);
					break;
				}
			}
		}
	}

	public function setList(anims:Array<Dynamic>, curAnim:Int)
	{
		_anims = anims != null ? anims : [];
		_curAnim = curAnim;
		_clamp();
		_scrollToVisible();
		_refresh();
	}

	public function setCurrent(curAnim:Int)
	{
		_curAnim = curAnim;
		_scrollToVisible();
		_refresh();
	}

	function _scrollToVisible()
	{
		if (_curAnim < _scrollY)
			_scrollY = _curAnim;
		else if (_curAnim >= _scrollY + _visibleRows)
			_scrollY = _curAnim - _visibleRows + 1;
		_clamp();
	}

	function _clamp()
	{
		var maxS:Int = Std.int(Math.max(0, _anims.length - _visibleRows));
		if (_scrollY < 0) _scrollY = 0;
		if (_scrollY > maxS) _scrollY = maxS;
	}

	function _refresh()
	{
		var isCheese:Bool = (ClientPrefs.data.uiTheme == 'Cheese');

		for (i in 0..._visibleRows)
		{
			var idx:Int = _scrollY + i;
			var anim:Dynamic = idx < _anims.length ? _anims[idx] : null;
			var sel:Bool = (anim != null && idx == _curAnim);

			if (anim != null)
			{
				if (isCheese)
				{
					_rowBgs[i].color = sel ? 0xFFF5C842 : 0xFFFFF8E7;
					_rowBgs[i].alpha = sel ? 0.92 : (i == _hoverRow ? 0.65 : 0.4);
					_rowTxts[i].color = 0xFF7A3D00;
				}
				else
				{
					_rowBgs[i].alpha = 0;
					_rowTxts[i].color = sel ? FlxColor.LIME : (i == _hoverRow ? FlxColor.YELLOW : FlxColor.WHITE);
				}
				_rowTxts[i].text = anim.anim + ': ' + anim.offsets;
			}
			else
			{
				_rowBgs[i].alpha = 0;
				_rowTxts[i].text = '';
			}
		}

		_refreshThumb();
	}

	function _refreshThumb()
	{
		if (_anims.length <= _visibleRows)
		{
			_sbarThumb.visible = false;
			return;
		}
		_sbarThumb.visible = true;

		var trackH:Float = listHeight - TITLE_H;
		var ratio:Float = _visibleRows / _anims.length;
		_sbarThumb.scale.y = Math.max(10.0 / trackH, ratio);

		var maxS:Int = Std.int(Math.max(1, _anims.length - _visibleRows));
		var thumbH:Float = trackH * _sbarThumb.scale.y;
		_sbarThumb.y = y + TITLE_H + Std.int((trackH - thumbH) * _scrollY / maxS);
	}

	function _redrawBg()
	{
		var isCheese:Bool = (ClientPrefs.data.uiTheme == 'Cheese');
		if (isCheese)
		{
			var bodyH:Int = listHeight - TITLE_H;
			_bg.makeGraphic(listWidth, listHeight, FlxColor.TRANSPARENT, true);
			_bg.alpha = 0.5;
			FlxSpriteUtil.drawRoundRect(_bg, 0, TITLE_H - 2, listWidth, bodyH + 2, 18, 18, 0xFFD47A00, {thickness: 0, color: FlxColor.TRANSPARENT});
			FlxSpriteUtil.drawRoundRect(_bg, 1, TITLE_H - 1, listWidth - 2, bodyH, 16, 16, 0xFFFFF0D0, {thickness: 0, color: FlxColor.TRANSPARENT});
			FlxSpriteUtil.drawRect(_bg, 1, TITLE_H - 1, listWidth - 2, 14, 0xFFFFF0D0);
			FlxSpriteUtil.drawRoundRect(_bg, 0, TITLE_H - 2, listWidth, bodyH + 2, 18, 18, FlxColor.TRANSPARENT, {thickness: 2, color: 0xFFD47A00});
			_bg.updateHitbox();
		}
		else
		{
			_bg.makeGraphic(listWidth, listHeight, FlxColor.WHITE);
			_bg.color = FlxColor.BLACK;
			_bg.alpha = 0.6;
		}
	}

	function _redrawTitleBg()
	{
		var isCheese:Bool = (ClientPrefs.data.uiTheme == 'Cheese');
		if (isCheese)
		{
			_titleBg.makeGraphic(listWidth, TITLE_H + 6, FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawRoundRect(_titleBg, 0, 0, listWidth, TITLE_H + 6, 14, 14, 0xFFFFFBEA, {thickness: 2, color: 0xFFE8A800});
			FlxSpriteUtil.drawRect(_titleBg, 2, TITLE_H - 2, listWidth - 4, 8, 0xFFFFFBEA);
			_titleBg.updateHitbox();
		}
		else
		{
			_titleBg.makeGraphic(listWidth, TITLE_H, FlxColor.WHITE);
			_titleBg.color = FlxColor.BLACK;
			_titleBg.alpha = 0.7;
		}
	}
}