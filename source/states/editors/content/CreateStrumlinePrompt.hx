package states.editors.content;

import states.editors.content.Prompt.BasePrompt;

typedef StrumlineConfigData =
{
	var character:String;
	var type:String;
	var stagePosition:String;
	var scale:Float;
	var spacing:Float;
	var hudX:Float;
	var hudY:Float;
	var visible:Bool;
	var scrollSpeed:Float;
	var usesChartScroll:Bool;
	var useExistingStrumline:Bool;
	var ?layer:Int;
}

class CreateStrumlinePrompt extends BasePrompt
{
	var _onSave:StrumlineConfigData->Void;
	var _onSaveAll:Array<StrumlineConfigData>->Void;
	var _onCancel:Void->Void;
	var _saved:Bool = false;
	var _strumIndex:Int;
	var _editConfigs:Array<StrumlineConfigData>;
	var _curEditIndex:Int = 0;
	var _loading:Bool = false;

	var _character:String = 'dad';
	var _characterList:Array<String> = ['dad'];
	var _type:String = 'OPPONENT';
	var _stagePos:String = 'DAD';
	var _scale:Float = 1;
	var _spacing:Float = 1;
	var _hudX:Float = 42;
	var _hudY:Float = 50;
	var _visible:Bool = true;
	var _scrollSpeed:Float = 1.3;
	var _usesChartScroll:Bool = true;
	var _useExistingStrumline:Bool = false;
	var _layer:Int = 0;

	var _typeDropDown:PsychUIDropDownMenu;
	var _selectDropDown:PsychUIDropDownMenu;
	var _useExistingCheck:PsychUICheckBox;
	var _charDropDown:PsychUIDropDownMenu;
	var _stagePosDropDown:PsychUIDropDownMenu;
	var _scaleStepper:PsychUINumericStepper;
	var _spacingStepper:PsychUINumericStepper;
	var _hudXStepper:PsychUINumericStepper;
	var _hudYStepper:PsychUINumericStepper;
	var _layerStepper:PsychUINumericStepper;
	var _scrollStepper:PsychUINumericStepper;
	var _visibleCheck:PsychUICheckBox;
	var _usesChartCheck:PsychUICheckBox;

	public function new(strumIndex:Int, onSave:StrumlineConfigData->Void, ?onCancel:Void->Void, ?characterList:Array<String>, ?editConfigs:Array<StrumlineConfigData>, ?onSaveAll:Array<StrumlineConfigData>->Void)
	{
		_strumIndex = strumIndex;
		_onSave = onSave;
		_onSaveAll = onSaveAll;
		_onCancel = onCancel;
		_characterList = characterList != null ? characterList : ['dad'];

		if(editConfigs != null)
		{
			_editConfigs = [];
			for(c in editConfigs)
				_editConfigs.push(Reflect.copy(c));
			super(420, 370, 'Edit strumlines', _buildPrompt);
		}
		else
		{
			super(420, 320, 'Creating strumline #$strumIndex', _buildPrompt);
		}
	}

	override function update(elapsed:Float)
	{
		FlxG.mouse.visible = true;
		super.update(elapsed);
	}

	function _loadEditConfig(index:Int)
	{
		var c:StrumlineConfigData = _editConfigs[index];
		_loading = true;

		_typeDropDown.selectedLabel = c.type;
		_charDropDown.selectedLabel = c.character;
		_stagePosDropDown.selectedLabel = c.stagePosition;
		_useExistingCheck.checked = c.useExistingStrumline;
		_visibleCheck.checked = c.visible;
		_scaleStepper.value = c.scale;
		_spacingStepper.value = c.spacing;
		_hudXStepper.value = c.hudX;
		_hudYStepper.value = c.hudY;
		_layerStepper.value = c.layer != null ? c.layer : 0;
		_scrollStepper.value = c.scrollSpeed;
		_usesChartCheck.checked = c.usesChartScroll;
		_scrollStepper.active = !c.usesChartScroll;
		_scrollStepper.alpha = c.usesChartScroll ? 0.4 : 1;

		_loading = false;
	}

	function _buildPrompt(_:BasePrompt)
	{
		var bx:Float = bg.x;
		var by:Float = bg.y;
		var pad:Float = 14;
		var col2:Float = bx + 214;
		var q:Float = 97;
		var yOff:Float = _editConfigs != null ? 50 : 0;

		var init:StrumlineConfigData = _editConfigs != null ? _editConfigs[0] : null;

		if(_editConfigs != null)
		{
			var selectLabel:FlxText = new FlxText(bx + pad, by + 50, 100, 'Edit strumline:');
			selectLabel.cameras = cameras;
			add(selectLabel);

			var strumNames:Array<String> = [];
			for(i in 0..._editConfigs.length)
				strumNames.push('Strumline #${i + 3}');

			var selectDropDown:PsychUIDropDownMenu = new PsychUIDropDownMenu(bx + pad, by + 63, strumNames, function(id:Int, val:String)
			{
				_curEditIndex = id;
				_loadEditConfig(id);
			});
			selectDropDown.cameras = cameras;
			_selectDropDown = selectDropDown;
		}

		var typeLabel:FlxText = new FlxText(bx + pad, by + 50 + yOff, 90, 'Type:');
		typeLabel.cameras = cameras;
		add(typeLabel);

		_typeDropDown = new PsychUIDropDownMenu(bx + pad, by + 63 + yOff, ['OPPONENT', 'PLAYER', 'ADDITIONAL'], function(id:Int, val:String)
		{
			if(_loading) return;
			if(_editConfigs != null) _editConfigs[_curEditIndex].type = val;
			else _type = val;
		});
		_typeDropDown.selectedLabel = init != null ? init.type : _type;
		_typeDropDown.cameras = cameras;

		_useExistingCheck = new PsychUICheckBox(col2, by + 68 + yOff, 'Use existing strumline', 180);
		_useExistingCheck.onClick = function()
		{
			if(_loading) return;
			if(_editConfigs != null) _editConfigs[_curEditIndex].useExistingStrumline = _useExistingCheck.checked;
			else _useExistingStrumline = _useExistingCheck.checked;
		};
		_useExistingCheck.checked = init != null ? init.useExistingStrumline : _useExistingStrumline;
		_useExistingCheck.cameras = cameras;
		add(_useExistingCheck);

		var charLabel:FlxText = new FlxText(bx + pad, by + 98 + yOff, 90, 'Character:');
		charLabel.cameras = cameras;
		add(charLabel);

		_charDropDown = new PsychUIDropDownMenu(bx + pad, by + 111 + yOff, _characterList, function(id:Int, val:String)
		{
			if(_loading) return;
			if(_editConfigs != null) _editConfigs[_curEditIndex].character = val;
			else _character = val;
		});
		_charDropDown.selectedLabel = init != null ? init.character : _character;
		_charDropDown.cameras = cameras;

		var stagePosLabel:FlxText = new FlxText(col2, by + 98 + yOff, 100, 'Stage position:');
		stagePosLabel.cameras = cameras;
		add(stagePosLabel);

		_stagePosDropDown = new PsychUIDropDownMenu(col2, by + 111 + yOff, ['DAD', 'BF', 'GF'], function(id:Int, val:String)
		{
			if(_loading) return;
			if(_editConfigs != null) _editConfigs[_curEditIndex].stagePosition = val;
			else _stagePos = val;
		});
		_stagePosDropDown.selectedLabel = init != null ? init.stagePosition : _stagePos;
		_stagePosDropDown.cameras = cameras;

		var scaleLabel:FlxText = new FlxText(bx + pad, by + 148 + yOff, 90, 'Scale:');
		scaleLabel.cameras = cameras;
		add(scaleLabel);

		_scaleStepper = new PsychUINumericStepper(bx + pad, by + 161 + yOff, 0.1, init != null ? init.scale : _scale, 0.1, 10, 1);
		_scaleStepper.onValueChange = function()
		{
			if(_loading) return;
			if(_editConfigs != null) _editConfigs[_curEditIndex].scale = _scaleStepper.value;
			else _scale = _scaleStepper.value;
		};
		_scaleStepper.cameras = cameras;
		add(_scaleStepper);

		var spacingLabel:FlxText = new FlxText(bx + pad + q, by + 148 + yOff, 90, 'Spacing:');
		spacingLabel.cameras = cameras;
		add(spacingLabel);

		_spacingStepper = new PsychUINumericStepper(bx + pad + q, by + 161 + yOff, 0.1, init != null ? init.spacing : _spacing, 0.1, 10, 1);
		_spacingStepper.onValueChange = function()
		{
			if(_loading) return;
			if(_editConfigs != null) _editConfigs[_curEditIndex].spacing = _spacingStepper.value;
			else _spacing = _spacingStepper.value;
		};
		_spacingStepper.cameras = cameras;
		add(_spacingStepper);

		var hudXLabel:FlxText = new FlxText(bx + pad + q * 2, by + 148 + yOff, 80, 'HUD X:');
		hudXLabel.cameras = cameras;
		add(hudXLabel);

		_hudXStepper = new PsychUINumericStepper(bx + pad + q * 2, by + 161 + yOff, 10, init != null ? init.hudX : _hudX, 0, 2000, 0);
		_hudXStepper.onValueChange = function()
		{
			if(_loading) return;
			if(_editConfigs != null) _editConfigs[_curEditIndex].hudX = _hudXStepper.value;
			else _hudX = _hudXStepper.value;
		};
		_hudXStepper.cameras = cameras;
		add(_hudXStepper);

		var hudYLabel:FlxText = new FlxText(bx + pad + q * 3, by + 148 + yOff, 60, 'HUD Y:');
		hudYLabel.cameras = cameras;
		add(hudYLabel);

		_hudYStepper = new PsychUINumericStepper(bx + pad + q * 3, by + 161 + yOff, 5, init != null ? init.hudY : _hudY, 0, 2000, 0);
		_hudYStepper.onValueChange = function()
		{
			if(_loading) return;
			if(_editConfigs != null) _editConfigs[_curEditIndex].hudY = _hudYStepper.value;
			else _hudY = _hudYStepper.value;
		};
		_hudYStepper.cameras = cameras;
		add(_hudYStepper);

		var layerLabel:FlxText = new FlxText(bx + pad, by + 198 + yOff, 90, 'Layer:');
		layerLabel.cameras = cameras;
		add(layerLabel);

		_layerStepper = new PsychUINumericStepper(bx + pad, by + 211 + yOff, 1, init != null ? (init.layer != null ? init.layer : 0) : _layer, Math.NEGATIVE_INFINITY, Math.POSITIVE_INFINITY, 0);
		_layerStepper.onValueChange = function()
		{
			if(_loading) return;
			if(_editConfigs != null) _editConfigs[_curEditIndex].layer = Std.int(_layerStepper.value);
			else _layer = Std.int(_layerStepper.value);
		};
		_layerStepper.cameras = cameras;
		add(_layerStepper);

		var scrollLabel:FlxText = new FlxText(bx + pad + q, by + 198 + yOff, 90, 'Scroll speed:');
		scrollLabel.cameras = cameras;
		add(scrollLabel);

		var initUsesChart:Bool = init != null ? init.usesChartScroll : _usesChartScroll;
		_scrollStepper = new PsychUINumericStepper(bx + pad + q, by + 211 + yOff, 0.1, init != null ? init.scrollSpeed : _scrollSpeed, 0.1, 10, 2);
		_scrollStepper.onValueChange = function()
		{
			if(_loading) return;
			if(_editConfigs != null) _editConfigs[_curEditIndex].scrollSpeed = _scrollStepper.value;
			else _scrollSpeed = _scrollStepper.value;
		};
		_scrollStepper.cameras = cameras;
		_scrollStepper.active = !initUsesChart;
		_scrollStepper.alpha = initUsesChart ? 0.4 : 1;
		add(_scrollStepper);

		_visibleCheck = new PsychUICheckBox(bx + pad + q * 2, by + 203 + yOff, 'Visible', 110);
		_visibleCheck.onClick = function()
		{
			if(_loading) return;
			if(_editConfigs != null) _editConfigs[_curEditIndex].visible = _visibleCheck.checked;
			else _visible = _visibleCheck.checked;
		};
		_visibleCheck.checked = init != null ? init.visible : _visible;
		_visibleCheck.cameras = cameras;
		add(_visibleCheck);

		_usesChartCheck = new PsychUICheckBox(bx + pad + q * 2, by + 223 + yOff, 'Chart speed', 110);
		_usesChartCheck.onClick = function()
		{
			if(_loading) return;
			var val:Bool = _usesChartCheck.checked;
			if(_editConfigs != null) _editConfigs[_curEditIndex].usesChartScroll = val;
			else _usesChartScroll = val;
			_scrollStepper.active = !val;
			_scrollStepper.alpha = val ? 0.4 : 1;
		};
		_usesChartCheck.checked = initUsesChart;
		_usesChartCheck.cameras = cameras;
		add(_usesChartCheck);

		var cancelBtn:PsychUIButton = new PsychUIButton(0, by + 258 + yOff, 'Cancel', close);
		cancelBtn.normalStyle.bgColor = FlxColor.RED;
		cancelBtn.normalStyle.textColor = FlxColor.WHITE;
		cancelBtn.screenCenter(X);
		cancelBtn.x -= 100;
		cancelBtn.cameras = cameras;
		add(cancelBtn);

		var saveBtn:PsychUIButton = new PsychUIButton(0, by + 258 + yOff, 'Save & Close', function()
		{
			_saved = true;
			if(_editConfigs != null)
			{
				if(_onSaveAll != null)
					_onSaveAll(_editConfigs);
			}
			else
			{
				if(_onSave != null)
				{
					_onSave({
						character: _character,
						type: _type,
						stagePosition: _stagePos,
						scale: _scale,
						spacing: _spacing,
						hudX: _hudX,
						hudY: _hudY,
						visible: _visible,
						scrollSpeed: _scrollSpeed,
						usesChartScroll: _usesChartScroll,
						useExistingStrumline: _useExistingStrumline,
						layer: _layer
					});
				}
			}
			close();
		});
		saveBtn.screenCenter(X);
		saveBtn.x += 100;
		saveBtn.cameras = cameras;
		add(saveBtn);

		add(_charDropDown);
		add(_stagePosDropDown);
		add(_typeDropDown);
		if(_selectDropDown != null)
			add(_selectDropDown);
	}

	override function close()
	{
		if(!_saved && _onCancel != null && _editConfigs == null)
			_onCancel();
		super.close();
	}
}
