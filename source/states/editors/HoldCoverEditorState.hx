package states.editors;

import objects.StrumNote;
import objects.HoldCover;

import openfl.net.FileFilter;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.input.keyboard.FlxKey;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;
import haxe.Json;
import shaders.RGBPalette.RGBShaderReference;
import objects.Note;

typedef HoldCoverAnimData = {
    var prefix:String;
    var fps:Array<Int>;
    var offsets:Array<Float>;
    var loop:Bool;
}

typedef HoldCoverConfig = {
    var animations:haxe.ds.StringMap<HoldCoverAnimData>;
    var scale:Float;
    var offsetNormal:Array<Float>;
    var offsetPixel:Array<Float>;
}

class HoldCoverEditorState extends MusicBeatState
{
    static var imageSkin:String = 'holdCovers/holdCoverRGB';

    var config:HoldCoverConfig;

    var strums:FlxTypedSpriteGroup<StrumNote> = new FlxTypedSpriteGroup();
    var covers:Array<FlxSprite> = [];

    var UI:PsychUIBox;
    var properUI:PsychUIBox;

    var curText:FlxText;
    var errorText:FlxText;

    var curNoteData:Int = 0;
    var curAnimName:String = 'hold';

    var copiedOffset:Array<Float> = [0, 0];
    var holdingArrowsTime:Float = 0;
    var holdingArrowsElapsed:Float = 0;

    var animDropDown:PsychUIDropDownMenu;
    var noteDropDown:PsychUIDropDownMenu;
    var imageInputText:PsychUIInputText;
    var scaleNumericStepper:PsychUINumericStepper;
    var prefixInput:PsychUIInputText;
    var minFpsStepper:PsychUINumericStepper;
    var maxFpsStepper:PsychUINumericStepper;
    var loopCheck:PsychUICheckBox;
    var normXStepper:PsychUINumericStepper;
    var normYStepper:PsychUINumericStepper;
    var pixXStepper:PsychUINumericStepper;
    var pixYStepper:PsychUINumericStepper;

    var _file:FileReference;
    var coverRgbShaders:Array<RGBShaderReference> = [];

    override function create()
    {
        FlxG.mouse.visible = true;

        FlxG.sound.volumeUpKeys = [];
        FlxG.sound.volumeDownKeys = [];
        FlxG.sound.muteKeys = [];

        #if DISCORD_ALLOWED
        #if MODS_ALLOWED
        DiscordClient.loadModRPC();
        #end
        DiscordClient.changePresence('Hold Cover Editor');
        #end

        config = createDefaultConfig();

        var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.scrollFactor.set();
        bg.color = 0xFF404040;
        add(bg);

        for (i in 0...4)
        {
            var strum:StrumNote = new StrumNote(-273, 50, i % 4, 1);
            strum.playerPosition();
            strum.screenCenter(Y);
            strum.ID = i;
            strums.add(strum);
        }

        add(strums);

        UI = new PsychUIBox(0, 0, 0, 0, ["Animation"]);
        UI.canMove = UI.canMinimize = false;
        UI.y = 0;
        UI.x = FlxG.width - 285;
        UI.resize(285, 265);

        properUI = new PsychUIBox(0, 0, 0, 0, ["Properties"]);
        properUI.canMove = properUI.canMinimize = false;
        properUI.resize(275, 295);
        properUI.y = 0;
        properUI.x = UI.x - properUI.width;

        add(properUI);
        add(UI);

        var f1Text:FlxText = new FlxText(5, 0, 0, "Press F1 for Help", 24);
        f1Text.setFormat(null, 24, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
        f1Text.borderSize = 1;
        f1Text.y = FlxG.height - 22 - f1Text.height - 2;
        add(f1Text);

        errorText = new FlxText();
        errorText.setFormat(null, 14, FlxColor.RED);
        errorText.text = "ERROR!";
        errorText.y = FlxG.height - errorText.height;
        errorText.alpha = 0;
        add(errorText);

        curText = new FlxText();
        curText.setFormat(null, 24, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        curText.text = '';
        curText.y = FlxG.height - 30;
        curText.x = 5;
        add(curText);

        addPropertiesTab();
        addAnimTab();

        reloadCovers();

        super.create();
    }

    function createDefaultConfig():HoldCoverConfig
    {
        var anims = new haxe.ds.StringMap<HoldCoverAnimData>();
        for (i in 0...4)
        {
            anims.set('hold_$i', {prefix: 'holdCoverRGB', fps: [24, 24], offsets: [-105.0, -100.0], loop: true});
            anims.set('end_$i',  {prefix: 'holdCoverEndRGB', fps: [24, 24], offsets: [-105.0, -100.0], loop: false});
        }
        return {
            animations: anims,
            scale: 1.0,
            offsetNormal: [-105, -100],
            offsetPixel: [-385, -125]
        };
    }

    function addPropertiesTab()
    {
        var ui = properUI.getTab("Properties").menu;

        ui.add(new FlxText(20, 8, 0, "Image:"));
        imageInputText = new PsychUIInputText(58, 8, 140, imageSkin, 8);
        ui.add(imageInputText);

        var reloadBtn:PsychUIButton = new PsychUIButton(203, 5, "Reload", function()
        {
            imageSkin = imageInputText.text;
            reloadCovers();
        });
        ui.add(reloadBtn);

        ui.add(new FlxText(20, 32, 0, "Scale:"));
        scaleNumericStepper = new PsychUINumericStepper(65, 30, 0.1, config.scale, 0.1, 10, 2, 60);
        ui.add(scaleNumericStepper);

        ui.add(new FlxText(20, 58, 0, "Normal Offset X:"));
        normXStepper = new PsychUINumericStepper(20, 73, 1, config.offsetNormal[0], -9999, 9999, 0);
        ui.add(normXStepper);

        ui.add(new FlxText(143, 58, 0, "Normal Offset Y:"));
        normYStepper = new PsychUINumericStepper(143, 73, 1, config.offsetNormal[1], -9999, 9999, 0);
        ui.add(normYStepper);

        ui.add(new FlxText(20, 98, 0, "Pixel Offset X:"));
        pixXStepper = new PsychUINumericStepper(20, 113, 1, config.offsetPixel[0], -9999, 9999, 0);
        ui.add(pixXStepper);

        ui.add(new FlxText(143, 98, 0, "Pixel Offset Y:"));
        pixYStepper = new PsychUINumericStepper(143, 113, 1, config.offsetPixel[1], -9999, 9999, 0);
        ui.add(pixYStepper);

        ui.add(new FlxText(20, 140, 0, "Note Skin:"));
        var noteSkinInput:PsychUIInputText = new PsychUIInputText(20, 155, 160, 'NOTE_assets', 8);
        ui.add(noteSkinInput);

        var applyNoteSkinBtn:PsychUIButton = new PsychUIButton(185, 152, "Apply", function()
        {
            for (strum in strums.members)
            {
                strum.texture = noteSkinInput.text;
                strum.playAnim('static', true);
            }
        });
        ui.add(applyNoteSkinBtn);

        var rgbCheck:PsychUICheckBox = new PsychUICheckBox(20, 183, "RGB Shader", 90);
        rgbCheck.checked = true;
        rgbCheck.onClick = function()
        {
            for (rgb in coverRgbShaders)
                rgb.enabled = rgbCheck.checked;
        };
        ui.add(rgbCheck);

        var antialiasCheck:PsychUICheckBox = new PsychUICheckBox(143, 183, "Antialiasing", 100);
        antialiasCheck.checked = ClientPrefs.data.antialiasing;
        antialiasCheck.onClick = function()
        {
            for (cover in covers)
                cover.antialiasing = antialiasCheck.checked;
        };
        ui.add(antialiasCheck);

        var saveBtn:PsychUIButton = new PsychUIButton(20, 212, "Save JSON", saveConfig);
        ui.add(saveBtn);

        var loadBtn:PsychUIButton = new PsychUIButton(155, 212, "Load JSON", loadConfig);
        ui.add(loadBtn);
    }

    function addAnimTab()
    {
        var ui = UI.getTab("Animation").menu;

        ui.add(new FlxText(20, 10, 0, "Note:"));

        ui.add(new FlxText(20, 65, 0, "Animation:"));

        ui.add(new FlxText(20, 120, 0, "Prefix:"));
        prefixInput = new PsychUIInputText(20, 137, 240, '', 8);
        ui.add(prefixInput);

        ui.add(new FlxText(20, 162, 0, "Min FPS:"));
        minFpsStepper = new PsychUINumericStepper(20, 179, 1, 24, 1, 120, 0);
        ui.add(minFpsStepper);

        ui.add(new FlxText(145, 162, 0, "Max FPS:"));
        maxFpsStepper = new PsychUINumericStepper(145, 179, 1, 24, 1, 120, 0);
        ui.add(maxFpsStepper);

        loopCheck = new PsychUICheckBox(20, 210, "Loop", 80);
        loopCheck.checked = true;
        ui.add(loopCheck);

        var applyBtn:PsychUIButton = new PsychUIButton(145, 207, "Apply Anim", function()
        {
            var key = animKey(curAnimName, curNoteData);
            var existing = config.animations.get(key);
            var offsets = existing != null ? existing.offsets : [0.0, 0.0];
            config.animations.set(key, {
                prefix: prefixInput.text,
                fps: [cast minFpsStepper.value, cast maxFpsStepper.value],
                offsets: offsets,
                loop: loopCheck.checked
            });
            reloadCovers();
        });
        ui.add(applyBtn);

        animDropDown = new PsychUIDropDownMenu(UI.x + 20, UI.y + 102, ['hold', 'end'], function(id:Int, name:String)
        {
            curAnimName = name;
            updateCoverAnim();
            updateAnimFields();
            updateAllCoverPositions();
        });
        add(animDropDown);

        noteDropDown = new PsychUIDropDownMenu(UI.x + 20, UI.y + 47, ['Left (0)', 'Down (1)', 'Up (2)', 'Right (3)'], function(id:Int, name:String)
        {
            curNoteData = id;
            for (i in 0...covers.length)
                covers[i].visible = (i == curNoteData);
            updateAnimFields();
            updateCoverAnim();
            updateCoverPositions();
        });
        add(noteDropDown);

        updateAnimFields();
    }

    function animKey(anim:String, noteData:Int):String
    {
        return anim + '_' + noteData;
    }

    function updateCoverAnim()
    {
        var i = curNoteData;
        if (i >= covers.length) return;
        var cover = covers[i];
        if (cover.animation.exists(curAnimName))
        {
            cover.animation.play(curAnimName, true);
            updateCoverPositions();
        }
        else
        {
            cover.animation.stop();
            errorText.color = FlxColor.RED;
            errorText.text = 'Animation "$curAnimName" not found in atlas!';
            errorText.alpha = 1;
            FlxTween.cancelTweensOf(errorText);
            FlxTween.tween(errorText, {alpha: 0}, 1, {startDelay: 2, onComplete: (_) -> errorText.color = FlxColor.RED});
        }
    }

    function updateAnimFields()
    {
        var key = animKey(curAnimName, curNoteData);
        var data = config.animations.get(key);
        if (data == null)
        {
            var base = config.animations.get(curAnimName);
            if (base != null)
            {
                prefixInput.text = base.prefix;
                minFpsStepper.value = base.fps[0];
                maxFpsStepper.value = base.fps[1];
                loopCheck.checked = base.loop;
            }
            else
            {
                prefixInput.text = curAnimName == 'hold' ? 'holdCoverRGB' : 'holdCoverEndRGB';
                minFpsStepper.value = 24;
                maxFpsStepper.value = 24;
                loopCheck.checked = curAnimName == 'hold';
            }
        }
        else
        {
            prefixInput.text = data.prefix;
            minFpsStepper.value = data.fps[0];
            maxFpsStepper.value = data.fps[1];
            loopCheck.checked = data.loop;
        }
    }

    function reloadCovers()
    {
        for (c in covers)
        {
            remove(c);
            c.destroy();
        }
        covers = [];
        coverRgbShaders = [];

        for (i in 0...4)
        {
            var strum = strums.members[i];
            var cover:FlxSprite = new FlxSprite();

            var path:String = imageSkin;
            if (Paths.fileExists('images/$path.png', IMAGE))
                cover.frames = Paths.getSparrowAtlas(path);
            else
                cover.frames = Paths.getSparrowAtlas('holdCovers/holdCoverRGB');

            var holdKey = animKey('hold', i);
            var holdData = config.animations.get(holdKey);
            var endKey = animKey('end', i);
            var endData = config.animations.get(endKey);

            if (holdData != null)
                cover.animation.addByPrefix('hold', holdData.prefix, holdData.fps[1], holdData.loop);
            if (endData != null)
                cover.animation.addByPrefix('end', endData.prefix, endData.fps[1], endData.loop);

            cover.scale.set(config.scale, config.scale);
            cover.updateHitbox();

            var animToPlay = (i == curNoteData) ? curAnimName : 'hold';
            var posKey = animKey(animToPlay, i);
            var posData = config.animations.get(posKey);
            var offsets = posData != null ? posData.offsets : config.offsetNormal.copy();
            cover.setPosition(strum.x + offsets[0], strum.y + offsets[1]);

            cover.animation.play(animToPlay, true);
            cover.visible = (i == curNoteData);
            cover.alpha = 0.85;

            var rgb = new RGBShaderReference(cover, Note.initializeGlobalRGBShader(i));
            var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[i];
            rgb.r = arr[0];
            rgb.g = arr[1];
            rgb.b = arr[2];
            rgb.enabled = true;
            coverRgbShaders.push(rgb);

            covers.push(cover);
            add(cover);
        }
    }

    function updateCoverPositions()
    {
        var i = curNoteData;
        if (i >= covers.length) return;
        var strum = strums.members[i];
        var cover = covers[i];
        var key = animKey(curAnimName, i);
        var data = config.animations.get(key);
        if (data != null)
            cover.setPosition(strum.x + data.offsets[0], strum.y + data.offsets[1]);

        cover.scale.set(config.scale, config.scale);
        cover.updateHitbox();
    }

    function updateAllCoverPositions()
    {
        for (i in 0...covers.length)
        {
            var strum = strums.members[i];
            var cover = covers[i];
            var animForCover = (i == curNoteData) ? curAnimName : 'hold';
            var key = animKey(animForCover, i);
            var data = config.animations.get(key);
            cover.scale.set(config.scale, config.scale);
            cover.updateHitbox();
            if (data != null)
                cover.setPosition(strum.x + data.offsets[0], strum.y + data.offsets[1]);
        }
    }

    var holdingArrows:Bool = false;
    override function update(elapsed:Float)
    {
        super.update(elapsed);

        noteDropDown.setPosition(UI.x + 20, UI.y + 27);
        animDropDown.setPosition(UI.x + 20, UI.y + 82);

        config.scale = scaleNumericStepper.value;
        config.offsetNormal = [normXStepper.value, normYStepper.value];
        config.offsetPixel = [pixXStepper.value, pixYStepper.value];

        errorText.x = FlxG.width - errorText.width - 5;

        var key = animKey(curAnimName, curNoteData);
        var data = config.animations.get(key);
        var offsets = data != null ? data.offsets : [0.0, 0.0];

        curText.text = 'Note: $curNoteData | Anim: $curAnimName | Offset: [${offsets[0]}, ${offsets[1]}] | Copied: [${copiedOffset[0]}, ${copiedOffset[1]}]';

        var blockInput:Bool = PsychUIInputText.focusOn != null;

        if (FlxG.keys.justPressed.F1)
        {
            openSubState(new HoldCoverEditorHelpSubState());
            return;
        }

        if (!blockInput)
        {
            if (FlxG.keys.pressed.CONTROL)
            {
                if (FlxG.keys.justPressed.C && data != null)
                    copiedOffset = data.offsets.copy();
                else if (FlxG.keys.justPressed.V && data != null)
                {
                    data.offsets = copiedOffset.copy();
                    config.animations.set(key, data);
                    updateCoverPositions();
                }
                else if (FlxG.keys.justPressed.R && data != null)
                {
                    data.offsets = [0.0, 0.0];
                    config.animations.set(key, data);
                    updateCoverPositions();
                }
            }

            var multiplier:Int = FlxG.keys.pressed.SHIFT ? 10 : 1;
            var moveKeysP = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];
            if (moveKeysP.contains(true) && data != null)
            {
                data.offsets[0] += ((moveKeysP[1] ? 1 : 0) - (moveKeysP[0] ? 1 : 0)) * multiplier;
                data.offsets[1] += ((moveKeysP[3] ? 1 : 0) - (moveKeysP[2] ? 1 : 0)) * multiplier;
                config.animations.set(key, data);
                updateCoverPositions();
            }

            if (FlxG.mouse.pressedRight && data != null && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0))
            {
                data.offsets[0] += FlxG.mouse.deltaScreenX;
                data.offsets[1] += FlxG.mouse.deltaScreenY;
                config.animations.set(key, data);
                updateCoverPositions();
            }

            var moveKeys = [FlxG.keys.pressed.LEFT, FlxG.keys.pressed.RIGHT, FlxG.keys.pressed.UP, FlxG.keys.pressed.DOWN];
            if (moveKeys.contains(true) && data != null)
            {
                holdingArrowsTime += elapsed;
                if (holdingArrowsTime > 0.6)
                {
                    holdingArrowsElapsed += elapsed;
                    while (holdingArrowsElapsed > (1 / 60))
                    {
                        data.offsets[0] += ((moveKeys[1] ? 1 : 0) - (moveKeys[0] ? 1 : 0)) * multiplier;
                        data.offsets[1] += ((moveKeys[3] ? 1 : 0) - (moveKeys[2] ? 1 : 0)) * multiplier;
                        holdingArrowsElapsed -= (1 / 60);
                    }
                    config.animations.set(key, data);
                    updateCoverPositions();
                }
            }
            else holdingArrowsTime = 0;

            if (FlxG.keys.justPressed.SPACE)
                updateCoverAnim();

            if (controls.BACK)
                backend.EditorHelper.returnToPreviousState();

            if (FlxG.mouse.overlaps(strums))
            {
                strums.forEach(function(strum:StrumNote)
                {
                    if (FlxG.mouse.overlaps(strum))
                    {
                        if (!FlxG.mouse.justPressed)
                        {
                            if (strum.animation.curAnim.name != 'pressed' && strum.animation.curAnim.name != 'confirm')
                                strum.playAnim('pressed');
                        }
                        else
                        {
                            strum.playAnim('confirm', true);
                            curNoteData = strum.ID;
                            noteDropDown.selectedIndex = strum.ID;
                            for (j in 0...covers.length)
                                covers[j].visible = (j == curNoteData);
                            updateCoverAnim();
                            updateAnimFields();
                        }
                    }
                    else strum.playAnim('static');
                });
            }
            else
            {
                for (strum in strums)
                    strum.playAnim('static');
            }
        }

        for (i in 0...4)
        {
            if (i >= covers.length) continue;
            var cover = covers[i];
            if (cover.animation.curAnim == null || !cover.animation.curAnim.finished) continue;
            var loopKey = animKey(cover.animation.curAnim.name, i);
            var loopData = config.animations.get(loopKey);
            if (loopData != null && loopData.loop)
                cover.animation.play(cover.animation.curAnim.name, true);
        }
    }

    function saveConfig()
    {
        var out:Dynamic = {
            scale: config.scale,
            offsetNormal: config.offsetNormal,
            offsetPixel: config.offsetPixel,
            animations: {}
        };

        for (k => v in config.animations)
        {
            Reflect.setField(out.animations, k, {
                prefix: v.prefix,
                fps: v.fps,
                offsets: v.offsets,
                loop: v.loop
            });
        }

        var data:String = Json.stringify(out, "\t");
        if (data.length > 0)
        {
            _file = new FileReference();
            _file.addEventListener(Event.COMPLETE, onSaveComplete);
            _file.addEventListener(Event.CANCEL, onSaveCancel);
            _file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
            _file.save(data, imageSkin.split('/').pop() + '.json');
        }
    }

    function loadConfig()
    {
        var jsonFilter:FileFilter = new FileFilter('Hold Cover JSON', '*.json');
        _file = new FileReference();
        _file.addEventListener(Event.SELECT, onLoadSelect);
        _file.addEventListener(Event.CANCEL, onLoadCancel);
        _file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
        _file.browse([#if !mac jsonFilter #end]);
    }

    function onLoadSelect(_):Void
    {
        _file.removeEventListener(Event.SELECT, onLoadSelect);
        _file.removeEventListener(Event.CANCEL, onLoadCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
        _file.load();
        _file.addEventListener(Event.COMPLETE, function(_)
        {
            try
            {
                var raw:Dynamic = Json.parse(_file.data.toString());
                var newConfig = createDefaultConfig();

                if (raw.scale != null) newConfig.scale = raw.scale;
                if (raw.offsetNormal != null) newConfig.offsetNormal = raw.offsetNormal;
                if (raw.offsetPixel != null) newConfig.offsetPixel = raw.offsetPixel;

                if (raw.animations != null)
                {
                    for (k in Reflect.fields(raw.animations))
                    {
                        var a:Dynamic = Reflect.field(raw.animations, k);
                        newConfig.animations.set(k, {
                            prefix: a.prefix,
                            fps: a.fps,
                            offsets: a.offsets,
                            loop: a.loop
                        });
                    }
                }

                config = newConfig;
                scaleNumericStepper.value = config.scale;
                normXStepper.value = config.offsetNormal[0];
                normYStepper.value = config.offsetNormal[1];
                pixXStepper.value  = config.offsetPixel[0];
                pixYStepper.value  = config.offsetPixel[1];
                updateAnimFields();
                reloadCovers();

                errorText.color = FlxColor.GREEN;
                errorText.text = 'Loaded successfully!';
                errorText.alpha = 1;
                FlxTween.cancelTweensOf(errorText);
                FlxTween.tween(errorText, {alpha: 0}, 1, {startDelay: 1, onComplete: (_) -> errorText.color = FlxColor.RED});
            }
            catch (e)
            {
                errorText.color = FlxColor.RED;
                errorText.text = 'ERROR loading JSON!';
                errorText.alpha = 1;
                FlxTween.cancelTweensOf(errorText);
                FlxTween.tween(errorText, {alpha: 0}, 1, {startDelay: 1});
            }
        });
    }

    function onSaveComplete(_):Void
    {
        _file.removeEventListener(Event.COMPLETE, onSaveComplete);
        _file.removeEventListener(Event.CANCEL, onSaveCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
        _file = null;
        FlxG.log.notice("Successfully saved file.");
    }

    function onSaveCancel(_):Void
    {
        _file.removeEventListener(Event.COMPLETE, onSaveComplete);
        _file.removeEventListener(Event.CANCEL, onSaveCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
        _file = null;
    }

    function onSaveError(_):Void
    {
        _file.removeEventListener(Event.COMPLETE, onSaveComplete);
        _file.removeEventListener(Event.CANCEL, onSaveCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
        _file = null;
        FlxG.log.error("Problem saving file");
    }

    function onLoadCancel(_):Void
    {
        _file.removeEventListener(Event.SELECT, onLoadSelect);
        _file.removeEventListener(Event.CANCEL, onLoadCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
        _file = null;
    }

    function onLoadError(_):Void
    {
        _file.removeEventListener(Event.SELECT, onLoadSelect);
        _file.removeEventListener(Event.CANCEL, onLoadCancel);
        _file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
        _file = null;
    }

    override function destroy()
    {
        super.destroy();
        FlxG.sound.muteKeys = [FlxKey.ZERO];
        FlxG.sound.volumeDownKeys = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
        FlxG.sound.volumeUpKeys = [FlxKey.NUMPADPLUS, FlxKey.PLUS];
    }
}
class HoldCoverEditorHelpSubState extends MusicBeatSubstate
{
    public function new()
    {
        super();

        var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.6;
        add(bg);

        var str:Array<String> = [
            "Click on a Strum to select it",
            "Space - Replay current animation",
            "",
            "Arrow Keys - Move offset (1px)",
            "Hold Shift - Move offset 10x faster",
            "Right Click + Drag - Move offset with mouse",
            "",
            "Ctrl + C - Copy current offset",
            "Ctrl + V - Paste copied offset",
            "Ctrl + R - Reset offset to [0, 0]",
            "",
            "Escape / Backspace - Return to previous state",
            "",
            "NOTE DATA:  Left: 0  |  Down: 1  |  Up: 2  |  Right: 3"
        ];

        for (i => txt in str)
        {
            if (txt.length < 1) continue;

            var helpText:FlxText = new FlxText(0, 0, 700, txt, 20);
            helpText.setFormat(null, 20, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
            helpText.borderSize = 1;
            helpText.screenCenter();
            helpText.y += ((i - str.length / 2) * 30) + 15;
            add(helpText);
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (controls.BACK || FlxG.keys.justPressed.F1)
            close();
    }
}