package backend;

import objects.Alphabet;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import states.TitleState;
import backend.StateManager;

class ModSelectorSubstate extends MusicBeatSubstate
{
	var modsList:Array<String> = [];
	var grpMods:FlxTypedGroup<Alphabet>;
	var curSelected:Int = 0;
	var bg:FlxSprite;
	var subCam:FlxCamera;
	var bgAnim:FlxSprite;
	var box:FlxSprite;
	var rayo:FlxSprite;

	function getCurrentModMode():String
	{
		var save:FlxSave = new FlxSave();
		save.bind('funkin', CoolUtil.getSavePath());
		
		if(save != null && save.data != null && save.data.modMode != null)
		{
			var mode:String = save.data.modMode;
			if(mode == 'MODS + FNF SONGS' || mode == 'ALL MODS' || mode == 'DISABLE MODS')
				return mode;
		}
		
		if(Mods.currentModDirectory != null && Mods.currentModDirectory != '')
			return 'SINGLE MOD';
		
		return 'DISABLE MODS';
	}

	public function new()
	{
		super();

		camera = subCam = new FlxCamera();
		subCam.bgColor = 0;
		FlxG.cameras.add(subCam, false);

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);
		
		FlxTween.tween(bg, {alpha: 0.5}, 0.25, {ease: FlxEase.cubeOut});

		bgAnim = new FlxSprite(0, 0);
		bgAnim.frames = Paths.getSparrowAtlas('mainmenu/ModSelector/bg');
		bgAnim.animation.addByPrefix('idle', 'idle', 6, true);
		bgAnim.animation.play('idle');
		bgAnim.setGraphicSize(FlxG.width, FlxG.height);
		bgAnim.updateHitbox();
		bgAnim.screenCenter();
		bgAnim.scrollFactor.set();
		bgAnim.alpha = 0;
		add(bgAnim);

		box = new FlxSprite(0, 0).loadGraphic(Paths.image('mainmenu/ModSelector/box'));
		box.setGraphicSize(FlxG.width, FlxG.height);
		box.updateHitbox();
		box.screenCenter();
		box.scrollFactor.set();
		box.alpha = 0;
		add(box);

		rayo = new FlxSprite(0, 0);
		rayo.frames = Paths.getSparrowAtlas('mainmenu/ModSelector/rayo');
		rayo.animation.addByPrefix('idle', 'idle', 6, true);
		rayo.animation.play('idle');
		rayo.setGraphicSize(FlxG.width, FlxG.height);
		rayo.updateHitbox();
		rayo.screenCenter();
		rayo.scrollFactor.set();
		rayo.alpha = 0;
		add(rayo);

		#if MODS_ALLOWED
		var modsDirectories = Mods.getModDirectories();
		for(mod in modsDirectories)
			modsList.push(mod);
		#end
		
		modsList.push("MODS + FNF SONGS");
		modsList.push("ALL MODS");
		modsList.push("DISABLE MODS");

		grpMods = new FlxTypedGroup<Alphabet>();
		add(grpMods);

		var currentMode = getCurrentModMode();
		
		for (i in 0...modsList.length)
		{
			var modText:Alphabet = new Alphabet(100, 100, modsList[i], true);
			modText.isMenuItem = true;
			modText.scrollFactor.set();
			modText.alpha = 0;
			modText.cameras = [subCam];
			
			var isCurrentMode = false;
			
			if(modsList[i] == "MODS + FNF SONGS" && currentMode == "MODS + FNF SONGS")
				isCurrentMode = true;
			else if(modsList[i] == "ALL MODS" && currentMode == "ALL MODS")
				isCurrentMode = true;
			else if(modsList[i] == "DISABLE MODS" && currentMode == "DISABLE MODS")
				isCurrentMode = true;
			else if(modsList[i] == Mods.currentModDirectory && currentMode == "SINGLE MOD")
				isCurrentMode = true;
			
			if(isCurrentMode)
			{
				modText.color = FlxColor.LIME;
				curSelected = i;
			}
			
			grpMods.add(modText);
		}

		changeSelection(0, true);

		FlxTween.tween(bgAnim, {alpha: 1}, 0.25, {ease: FlxEase.cubeOut});
		FlxTween.tween(box, {alpha: 1}, 0.25, {ease: FlxEase.cubeOut});
		FlxTween.tween(rayo, {alpha: 1}, 0.25, {ease: FlxEase.cubeOut});
		
		for (k => modText in grpMods.members)
		{
			var targetAlpha:Float = (k == curSelected) ? 1 : 0.6;
			FlxTween.tween(modText, {alpha: targetAlpha}, 0.25, {ease: FlxEase.cubeOut});
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		changeSelection((controls.UI_DOWN_P ? 1 : 0) + (controls.UI_UP_P ? -1 : 0) - FlxG.mouse.wheel);

		if (controls.BACK || FlxG.keys.justPressed.TAB)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxTween.tween(bgAnim, {alpha: 0}, 0.25, {ease: FlxEase.cubeOut});
			FlxTween.tween(box, {alpha: 0}, 0.25, {ease: FlxEase.cubeOut});
			FlxTween.tween(rayo, {alpha: 0}, 0.25, {ease: FlxEase.cubeOut});
			FlxTween.tween(bg, {alpha: 0}, 0.25, {ease: FlxEase.cubeOut});
			
			for (modText in grpMods.members)
			{
				FlxTween.tween(modText, {alpha: 0}, 0.25, {ease: FlxEase.cubeOut});
			}
			
			new FlxTimer().start(0.25, function(tmr:FlxTimer) {
				close();
			});
		}

		if (controls.ACCEPT)
		{
			#if MODS_ALLOWED
			var selectedMod = modsList[curSelected];
			var save:FlxSave = new FlxSave();
			save.bind('funkin', CoolUtil.getSavePath());
			
			if(selectedMod == "MODS + FNF SONGS")
		{
			Mods.currentModDirectory = '';
			if(save != null && save.data != null)
			{
				save.data.currentMod = '';
				save.data.modMode = 'MODS + FNF SONGS';
			}
			save.flush();
			#if DISCORD_ALLOWED
			backend.DiscordClient.resetClientID();
			#end
			
			Mods.loadTopMod();
		}
		else if(selectedMod == "ALL MODS")
		{
			Mods.currentModDirectory = '';
			if(save != null && save.data != null)
			{
				save.data.currentMod = '';
				save.data.modMode = 'ALL MODS';
			}
			save.flush();
			#if DISCORD_ALLOWED
			backend.DiscordClient.resetClientID();
			#end
			
			Mods.loadTopMod();
		}
			else if(selectedMod == "DISABLE MODS")
			{
				Mods.currentModDirectory = '';
				if(save != null && save.data != null)
				{
					save.data.currentMod = '';
					save.data.modMode = 'DISABLE MODS';
				}
				save.flush();
				#if DISCORD_ALLOWED
				backend.DiscordClient.resetClientID();
				#end
			}
			else
			{
				Mods.setActiveMod(selectedMod);
				if(save != null && save.data != null)
					save.data.modMode = 'SINGLE MOD';
				save.flush();
			}
			
			#if sys
			var modsListContent:String = '';
			var allModsDirectories = Mods.getModDirectories();
			for(mod in allModsDirectories)
			{
				if(selectedMod == "ALL MODS" || selectedMod == "MODS + FNF SONGS")
					modsListContent += mod + '|1\n';
				else if(mod == selectedMod && selectedMod != "DISABLE MODS")
					modsListContent += mod + '|1\n';
				else
					modsListContent += mod + '|0\n';
			}
			sys.io.File.saveContent('modsList.txt', modsListContent);
			Mods.updatedOnState = false;
			#end
			
			FlxG.sound.play(Paths.sound('confirmMenu'));
			FlxTween.tween(bgAnim, {alpha: 0}, 0.25, {ease: FlxEase.cubeOut});
			FlxTween.tween(box, {alpha: 0}, 0.25, {ease: FlxEase.cubeOut});
			FlxTween.tween(rayo, {alpha: 0}, 0.25, {ease: FlxEase.cubeOut});
			FlxTween.tween(bg, {alpha: 0}, 0.25, {ease: FlxEase.cubeOut});
			
			for (modText in grpMods.members)
			{
				FlxTween.tween(modText, {alpha: 0}, 0.25, {ease: FlxEase.cubeOut});
			}
			
			new FlxTimer().start(0.25, function(tmr:FlxTimer) {
				completeReset();
			});
			#end
		}
	}
	
	function completeReset()
	{
		if(FlxG.sound.music != null)
		{
			try {
				FlxG.sound.music.stop();
				FlxG.sound.music = null;
			} catch(e:Dynamic) {}
		}
		
		#if MODS_ALLOWED
		try {
			Mods.updatedOnState = false;
			var currentMode = getCurrentModMode();
			
			if(currentMode == 'MODS + FNF SONGS' || currentMode == 'ALL MODS' || currentMode == 'DISABLE MODS')
			{
				Mods.loadTopMod();
				Mods.currentModDirectory = '';
			}
			else
			{
				Mods.loadTopMod();
			}
		} catch(e:Dynamic) {}
		#end
		
		#if DISCORD_ALLOWED
		try {
			backend.DiscordClient.loadModRPC();
			backend.DiscordClient.changePresence();
		} catch(e:Dynamic) {}
		#end

		#if MODS_ALLOWED
		try {
			var currentMode = getCurrentModMode();
			
			if(currentMode == 'MODS + FNF SONGS' || currentMode == 'ALL MODS' || currentMode == 'DISABLE MODS')
			{
				lime.app.Application.current.window.title = "Friday Night Funkin': Psych Engine";
				
				try {
					lime.app.Application.current.window.setIcon(null);
					
					var defaultIconPath:String = "icon.png";
					if (sys.FileSystem.exists(defaultIconPath))
					{
						var iconImage = lime.graphics.Image.fromFile(defaultIconPath);
						if(iconImage != null)
						{
							lime.app.Application.current.window.setIcon(iconImage);
						}
					}
				} catch(e:Dynamic) {}
			}
			else
			{
				var pack:Dynamic = Mods.getPack();
				var newTitle:String = "Friday Night Funkin': Psych Engine";
				if (pack != null && pack.name != null)
					newTitle = pack.name;
				lime.app.Application.current.window.title = newTitle;
				winapi.WindowsCPP.reDefineMainWindowTitle(newTitle);

				Main.applyModWindowColor();

				var iconPath:String = Paths.modFolders('pack.png');
				if (sys.FileSystem.exists(iconPath))
				{
					var icon = lime.graphics.Image.fromFile(iconPath);
					lime.app.Application.current.window.setIcon(icon);
				}
				else
				{
					var defaultIconPath:String = "icon.png";
					if (sys.FileSystem.exists(defaultIconPath))
					{
						var icon = lime.graphics.Image.fromFile(defaultIconPath);
						lime.app.Application.current.window.setIcon(icon);
					}
				}
			}
		} catch(e:Dynamic) {}
		#end
		
		try {
			backend.WeekData.reloadWeekFiles(false);
		} catch(e:Dynamic) {}
		
		try {
			backend.Highscore.load();
		} catch(e:Dynamic) {}
		
		TitleState.initialized = false;
		TitleState.closedState = false;
		
		FlxTransitionableState.skipNextTransIn = false;
		FlxTransitionableState.skipNextTransOut = false;
		
		var hscriptState = HScriptStateLoader.loadStateScript('TitleState');
		if(hscriptState != null)
		{
			MusicBeatState.switchState(hscriptState);
		}
		else
		{
			var stateClass = backend.StateManager.getStateClass('TitleState');
			if(stateClass != null)
			{
				var stateInstance = Type.createInstance(stateClass, []);
				MusicBeatState.switchState(stateInstance);
			}
		}
	}

	function changeSelection(change:Int = 0, force:Bool = false)
	{
		if (change == 0 && !force) return;
		
		var previousSelected = curSelected;
		curSelected = FlxMath.wrap(curSelected + change, 0, grpMods.length - 1);
		
		if(change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.7);

		for (k => alphabet in grpMods.members)
		{
			var prevTargetY = alphabet.targetY;
			alphabet.targetY = k - curSelected;
			
			var yPos = 130 + (alphabet.targetY * 120);
			var targetAlpha:Float = 0;
			
			var topLimit:Float = 120;
			var bottomLimit:Float = FlxG.height - 140;
			var fadeZone:Float = 60;
			
			FlxTween.cancelTweensOf(alphabet);
			
			var isEnteringFromTop:Bool = (prevTargetY < alphabet.targetY) && (alphabet.alpha == 0);
			var isEnteringFromBottom:Bool = (prevTargetY > alphabet.targetY) && (alphabet.alpha == 0);
			
			if (isEnteringFromTop && yPos >= topLimit && yPos <= bottomLimit)
			{
				alphabet.alpha = 0;
			}
			else if (isEnteringFromBottom && yPos >= topLimit && yPos <= bottomLimit)
			{
				alphabet.alpha = 0;
			}
			
			if (yPos < topLimit - fadeZone || yPos > bottomLimit + fadeZone)
			{
				targetAlpha = 0;
			}
			else if (yPos < topLimit)
			{
				var fadeProgress = (yPos - (topLimit - fadeZone)) / fadeZone;
				targetAlpha = (k == curSelected) ? fadeProgress : fadeProgress * 0.6;
			}
			else if (yPos > bottomLimit)
			{
				var fadeProgress = ((bottomLimit + fadeZone) - yPos) / fadeZone;
				targetAlpha = (k == curSelected) ? fadeProgress : fadeProgress * 0.6;
			}
			else
			{
				targetAlpha = (k == curSelected) ? 1 : 0.6;
			}
			
			FlxTween.tween(alphabet, {alpha: targetAlpha}, 0.1, {ease: FlxEase.linear});
		}
	}

	override function destroy()
	{
		super.destroy();
		if (FlxG.cameras.list.contains(subCam))
			FlxG.cameras.remove(subCam);
	}
}