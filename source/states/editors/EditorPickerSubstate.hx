package states.editors;

import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxSpriteGroup;
import flixel.effects.FlxFlicker;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.tweens.FlxEase;
import backend.MusicBeatSubstate;
import states.editors.*;
import objects.Alphabet;

typedef EditorOption = {
	var name:String;
	var id:String;
	var state:Class<MusicBeatState>;
}

class EditorPickerSubstate extends MusicBeatSubstate {
	public var bg:FlxSprite;
	
	public var options:Array<EditorOption> = [
		{
			name: "Chart Editor",
			id: "chart",
			state: ChartingState
		},
		{
			name: "Character Editor",
			id: "character",
			state: CharacterEditorState
		},
		{
			name: "Stage Editor",
			id: "stage",
			state: StageEditorState
		},
		{
			name: "Week Editor",
			id: "week",
			state: WeekEditorState
		},
		{
			name: "Menu Character Editor",
			id: "menucharacter",
			state: MenuCharacterEditorState
		},
		{
			name: "Dialogue Editor",
			id: "dialogue",
			state: DialogueEditorState
		},
		{
			name: "Dialogue Portrait Editor",
			id: "dialogueportrait",
			state: DialogueCharacterEditorState
		},
		{
			name: "Note Splash Editor",
			id: "notesplash",
			state: NoteSplashEditorState
		},
		{
			name: "Hold Cover Editor",
			id: "holdcover",
			state: HoldCoverEditorState
		}
	];
	
	public var sprites:Array<EditorPickerOption> = [];
	public var curSelected:Int = 0;
	public var subCam:FlxCamera;
	public var oldMousePos:FlxPoint = FlxPoint.get();
	public var curMousePos:FlxPoint = FlxPoint.get();
	public var optionHeight:Float = 0;
	public var selected:Bool = false;
	public var camVelocity:Float = 0;
	
	override function create() {
		super.create();
		
		camera = subCam = new FlxCamera();
		subCam.bgColor = 0;
		FlxG.cameras.add(subCam, false);
		
		bg = new FlxSprite().makeGraphic(1, 1, 0xFF000000);
		bg.scrollFactor.set();
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.alpha = 0;
		add(bg);
		
		optionHeight = FlxG.height / options.length;
		for(k => o in options) {
			var spr = new EditorPickerOption(o.name, o.id, optionHeight);
			spr.y = k * optionHeight;
			add(spr);
			sprites.push(spr);
		}
		sprites[0].selected = true;
		
		FlxG.mouse.getScreenPosition(subCam, oldMousePos);
	}
	
	override function update(elapsed:Float) {
		super.update(elapsed);
		
		bg.alpha = FlxMath.lerp(bg.alpha, selected ? 1 : 0.5, Math.min(elapsed * 12, 1));
		
		if (selected) {
			camVelocity += FlxG.width * elapsed * 2;
			subCam.scroll.x += camVelocity * elapsed;
			return;
		}
		
		var scrollChange:Int = 0;
		if(controls.UI_UP_P) scrollChange = -1;
		if(controls.UI_DOWN_P) scrollChange = 1;
		if(FlxG.mouse.wheel != 0) scrollChange = -FlxG.mouse.wheel;
		changeSelection(scrollChange);
		
		FlxG.mouse.getScreenPosition(subCam, curMousePos);
		if (curMousePos.x != oldMousePos.x || curMousePos.y != oldMousePos.y) {
			oldMousePos.set(curMousePos.x, curMousePos.y);
			var mouseSelection:Int = Std.int(curMousePos.y / optionHeight);
			if(mouseSelection >= 0 && mouseSelection < options.length && mouseSelection != curSelected) {
				curSelected = mouseSelection;
				changeSelection(0);
			}
		}
		
		if (controls.ACCEPT || FlxG.mouse.justPressed) {
				selected = true;
				FlxG.sound.play(Paths.sound('confirmMenu'));
				
				if (FlxG.sound.music != null)
					FlxG.sound.music.fadeOut(0.7, 0, function(n) {
						FlxG.sound.music.stop();
					});
				
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				
				subCam.fade(0xFF000000, 0.5, false, function() {
					sprites[curSelected].flicker(function() {
						backend.EditorHelper.saveCurrentState();
						MusicBeatState.switchState(Type.createInstance(options[curSelected].state, []));
					});
				});
			}
		
		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
		}
	}
	
	override function destroy() {
		super.destroy();
		oldMousePos.put();
		curMousePos.put();
		if (FlxG.cameras.list.contains(subCam))
			FlxG.cameras.remove(subCam);
	}
	
	public function changeSelection(change:Int) {
		if (change == 0 && curSelected >= 0 && curSelected < sprites.length) {
			for(o in sprites)
				o.selected = false;
			sprites[curSelected].selected = true;
			return;
		}
		
		if (change == 0) return;
		
		FlxG.sound.play(Paths.sound('scrollMenu'));
		curSelected = FlxMath.wrap(curSelected + change, 0, sprites.length - 1);
		
		for(o in sprites)
			o.selected = false;
		sprites[curSelected].selected = true;
	}
}

class EditorPickerOption extends FlxSpriteGroup {
	public var iconSpr:FlxSprite;
	public var label:Alphabet;
	public var selectionBG:FlxSprite;
	public var selected:Bool = false;
	public var selectionLerp:Float = 0;
	public var iconRotationCycle:Float = 0;
	
	public function new(name:String, iconID:String, height:Float) {
		super();
		
		FlxG.mouse.visible = true;
		
		iconSpr = new FlxSprite();
		iconSpr.loadGraphic(Paths.image('editors/icons/$iconID'));
		iconSpr.antialiasing = ClientPrefs.data.antialiasing;
		iconSpr.setGraphicSize(Std.int(110), Std.int(110));
		iconSpr.updateHitbox();
		iconSpr.x = 25 + ((height - iconSpr.width) / 2);
		iconSpr.y = (height - iconSpr.height) / 2;
		
		label = new Alphabet(25 + iconSpr.width + 25, 0, name, true);
		label.y = (height - label.height) / 2;
		
		selectionBG = new FlxSprite().makeGraphic(1, 1, -1);
		selectionBG.scale.set(FlxG.width, height);
		selectionBG.updateHitbox();
		selectionBG.alpha = 0;
		
		add(selectionBG);
		add(iconSpr);
		add(label);
	}
	
	override function update(elapsed:Float) {
		super.update(elapsed);
		iconRotationCycle += elapsed;
		
		selectionLerp = FlxMath.lerp(selectionLerp, selected ? 1 : 0, Math.min(elapsed * 12, 1));
		
		selectionBG.alpha = (iconSpr.alpha = FlxEase.cubeOut(selectionLerp)) * 0.5;
		selectionBG.x = FlxMath.lerp(-FlxG.width, 0, selectionLerp);
		
		label.x = FlxMath.lerp(10, 25 + iconSpr.width + 25, selectionLerp);
		iconSpr.x = label.x - 25 - iconSpr.width;
		
		scrollFactor.set(FlxMath.lerp(1, 0.1, selectionLerp), 0);
		selectionBG.scrollFactor.set(0, 0);
	}
	
	public function flicker(callback:Void->Void) {
		FlxFlicker.flicker(label, 0.5, ClientPrefs.data.flashing ? 0.06 : 0.15, false, false, function(t) {
			callback();
		});
	}
}