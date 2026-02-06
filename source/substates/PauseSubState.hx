package substates;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.util.FlxStringUtil;

import states.StoryMenuState;
import states.FreeplayState;
import options.OptionsState;
import substates.StickerSubState;

#if HSCRIPT_ALLOWED
import backend.HScriptStateLoader.HScriptState;
#end
class PauseSubState extends MusicBeatSubstate
{
	var grpMenuShit:FlxTypedGroup<Alphabet>;

	var menuItems:Array<String> = [];
	var menuItemsOG:Array<String> = ['Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'];
	var difficultyChoices = [];
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;
	var practiceText:FlxText;
	var skipTimeText:FlxText;
	var skipTimeTracker:Alphabet;
	var curTime:Float = Math.max(0, Conductor.songPosition);

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	public static var songName:String = null;

	var rotatingCreditText:FlxText;
	var creditRotationTimer:FlxTimer;
	var creditFadeTween:FlxTween;
	var currentCreditIndex:Int = 0;
	var creditsList:Array<String> = [];

	override function create()
	{
		PlayState.songmeta = backend.MetaData.parse(Paths.formatToSongPath(PlayState.SONG.song));

		if(Difficulty.list.length < 2) menuItemsOG.remove('Change Difficulty'); //No need to change difficulty if there is only one!
		if(PlayState.chartingMode)
		{
			menuItemsOG.insert(2, 'Leave Charting Mode');
			var num:Int = 0;
			if(!PlayState.instance.startingSong)
			{
				num = 1;
				menuItemsOG.insert(3, 'Skip Time');
			}
			menuItemsOG.insert(3 + num, 'End Song');
			menuItemsOG.insert(4 + num, 'Toggle Practice Mode');
			menuItemsOG.insert(5 + num, 'Toggle Botplay');
		} else if(PlayState.instance.practiceMode && !PlayState.instance.startingSong)
			menuItemsOG.insert(3, 'Skip Time');
		menuItems = menuItemsOG;

		for (i in 0...Difficulty.list.length) {
			var diff:String = Difficulty.getString(i);
			difficultyChoices.push(diff);
		}
		difficultyChoices.push('BACK');

		pauseMusic = new FlxSound();
		try
		{
			var pauseSong:String = getPauseSong();
			if(pauseSong != null) pauseMusic.loadEmbedded(Paths.music(pauseSong), true, true);
		}
		catch(e:Dynamic) {}
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));

		FlxG.sound.list.add(pauseMusic);

		var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var displaySongName:String = PlayState.SONG.song.replace("-", " ");
		var words:Array<String> = displaySongName.split(" ");
		for (i in 0...words.length)
		{
			if(words[i].length > 0)
				words[i] = words[i].charAt(0).toUpperCase() + words[i].substr(1).toLowerCase();
		}
		displaySongName = words.join(" ");

		var levelInfo:FlxText = new FlxText(20, 15, 0, displaySongName, 32);
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32);
		levelInfo.updateHitbox();
		add(levelInfo);

		var currentY:Float = levelInfo.y + 32;
		var artisttxt:FlxText = null;
		var composertxt:FlxText = null;
		var chartertxt:FlxText = null;
		var codertxt:FlxText = null;

		trace("=== PAUSE METADATA DEBUG ===");
		trace("PlayState.songmeta: " + PlayState.songmeta);
		if (PlayState.songmeta != null)
		{
			trace("creditsA: " + PlayState.songmeta.creditsA);
			trace("creditsCO: " + PlayState.songmeta.creditsCO);
			trace("creditsCH: " + PlayState.songmeta.creditsCH);
			trace("creditsCOD: " + PlayState.songmeta.creditsCOD);
		}

		var hasValidMetadata:Bool = false;
		if (PlayState.songmeta != null)
		{
			if((PlayState.songmeta.creditsA != null && PlayState.songmeta.creditsA.length > 0 && PlayState.songmeta.creditsA[0] != "") ||
			   (PlayState.songmeta.creditsCO != null && PlayState.songmeta.creditsCO.length > 0 && PlayState.songmeta.creditsCO[0] != "") ||
			   (PlayState.songmeta.creditsCH != null && PlayState.songmeta.creditsCH.length > 0 && PlayState.songmeta.creditsCH[0] != "") ||
			   (PlayState.songmeta.creditsCOD != null && PlayState.songmeta.creditsCOD.length > 0 && PlayState.songmeta.creditsCOD[0] != ""))
			{
				hasValidMetadata = true;
			}
		}
		trace("hasValidMetadata: " + hasValidMetadata);
		trace("=== END DEBUG ===");

		if (hasValidMetadata)
		{
			if(PlayState.songmeta.showAllCredits)
			{
				if(PlayState.songmeta.creditsA != null && PlayState.songmeta.creditsA.length > 0 && PlayState.songmeta.creditsA[0] != "")
				{
					artisttxt = new FlxText(0, currentY, 0, "Artist: " + PlayState.songmeta.creditsA.join(", "), 32);
					artisttxt.scrollFactor.set();
					artisttxt.setFormat(Paths.font('vcr.ttf'), 32);
					artisttxt.updateHitbox();
					artisttxt.x = FlxG.width - (artisttxt.width + 20);
					artisttxt.alpha = 0;
					add(artisttxt);
					currentY += 32;
				}

				if(PlayState.songmeta.creditsCO != null && PlayState.songmeta.creditsCO.length > 0 && PlayState.songmeta.creditsCO[0] != "")
				{
					composertxt = new FlxText(0, currentY, 0, "Composer: " + PlayState.songmeta.creditsCO.join(", "), 32);
					composertxt.scrollFactor.set();
					composertxt.setFormat(Paths.font('vcr.ttf'), 32);
					composertxt.updateHitbox();
					composertxt.x = FlxG.width - (composertxt.width + 20);
					composertxt.alpha = 0;
					add(composertxt);
					currentY += 32;
				}

				if(PlayState.songmeta.creditsCH != null && PlayState.songmeta.creditsCH.length > 0 && PlayState.songmeta.creditsCH[0] != "")
				{
					chartertxt = new FlxText(0, currentY, 0, "Charter: " + PlayState.songmeta.creditsCH.join(", "), 32);
					chartertxt.scrollFactor.set();
					chartertxt.setFormat(Paths.font('vcr.ttf'), 32);
					chartertxt.updateHitbox();
					chartertxt.x = FlxG.width - (chartertxt.width + 20);
					chartertxt.alpha = 0;
					add(chartertxt);
					currentY += 32;
				}

				if(PlayState.songmeta.creditsCOD != null && PlayState.songmeta.creditsCOD.length > 0 && PlayState.songmeta.creditsCOD[0] != "")
				{
					codertxt = new FlxText(0, currentY, 0, "Coder: " + PlayState.songmeta.creditsCOD.join(", "), 32);
					codertxt.scrollFactor.set();
					codertxt.setFormat(Paths.font('vcr.ttf'), 32);
					codertxt.updateHitbox();
					codertxt.x = FlxG.width - (codertxt.width + 20);
					codertxt.alpha = 0;
					add(codertxt);
					currentY += 32;
				}
			}
			else
			{
				if(PlayState.songmeta.creditsA != null && PlayState.songmeta.creditsA.length > 0 && PlayState.songmeta.creditsA[0] != "")
					creditsList.push("Artist: " + PlayState.songmeta.creditsA.join(", "));
				
				if(PlayState.songmeta.creditsCO != null && PlayState.songmeta.creditsCO.length > 0 && PlayState.songmeta.creditsCO[0] != "")
					creditsList.push("Composer: " + PlayState.songmeta.creditsCO.join(", "));
				
				if(PlayState.songmeta.creditsCH != null && PlayState.songmeta.creditsCH.length > 0 && PlayState.songmeta.creditsCH[0] != "")
					creditsList.push("Charter: " + PlayState.songmeta.creditsCH.join(", "));
				
				if(PlayState.songmeta.creditsCOD != null && PlayState.songmeta.creditsCOD.length > 0 && PlayState.songmeta.creditsCOD[0] != "")
					creditsList.push("Coder: " + PlayState.songmeta.creditsCOD.join(", "));

				if(creditsList.length > 0)
				{
					rotatingCreditText = new FlxText(0, currentY, 0, creditsList[0], 32);
					rotatingCreditText.scrollFactor.set();
					rotatingCreditText.setFormat(Paths.font('vcr.ttf'), 32);
					rotatingCreditText.updateHitbox();
					rotatingCreditText.x = FlxG.width - (rotatingCreditText.width + 20);
					rotatingCreditText.alpha = 0;
					add(rotatingCreditText);
					currentY += 32;
				}
			}
		}

		var levelDifficulty:FlxText = new FlxText(20, currentY, 0, Difficulty.getString().toUpperCase(), 32);
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), 32);
		levelDifficulty.updateHitbox();
		add(levelDifficulty);

		var blueballedTxt:FlxText = new FlxText(20, currentY + 32, 0, Language.getPhrase("blueballed", "Blueballed: {1}", [PlayState.deathCounter]), 32);
		blueballedTxt.scrollFactor.set();
		blueballedTxt.setFormat(Paths.font('vcr.ttf'), 32);
		blueballedTxt.updateHitbox();
		add(blueballedTxt);

		blueballedTxt.alpha = 0;
		levelDifficulty.alpha = 0;
		levelInfo.alpha = 0;

		levelInfo.x = FlxG.width - (levelInfo.width + 20);
		levelDifficulty.x = FlxG.width - (levelDifficulty.width + 20);
		blueballedTxt.x = FlxG.width - (blueballedTxt.width + 20);

		FlxTween.tween(levelInfo, {alpha: 1, y: levelInfo.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});

		var tweenDelay:Float = 0.5;
		
		if(PlayState.songmeta.showAllCredits)
		{
			if(artisttxt != null)
			{
				FlxTween.tween(artisttxt, {alpha: 1, y: artisttxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: tweenDelay});
				tweenDelay += 0.2;
			}
			if(composertxt != null)
			{
				FlxTween.tween(composertxt, {alpha: 1, y: composertxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: tweenDelay});
				tweenDelay += 0.2;
			}
			if(chartertxt != null)
			{
				FlxTween.tween(chartertxt, {alpha: 1, y: chartertxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: tweenDelay});
				tweenDelay += 0.2;
			}
			if(codertxt != null)
			{
				FlxTween.tween(codertxt, {alpha: 1, y: codertxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: tweenDelay});
				tweenDelay += 0.2;
			}
		}
		else
		{
			if(rotatingCreditText != null)
			{
				FlxTween.tween(rotatingCreditText, {alpha: 1, y: rotatingCreditText.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: tweenDelay});
				tweenDelay += 0.2;
				
				startCreditRotation();
			}
		}

		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: tweenDelay});
		FlxTween.tween(blueballedTxt, {alpha: 1, y: blueballedTxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: tweenDelay + 0.2});

		if(chartertxt != null)
		{
			FlxTween.tween(chartertxt, {alpha: 1, y: chartertxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: tweenDelay});
			tweenDelay += 0.2;
		}
		if(codertxt != null)
		{
			FlxTween.tween(codertxt, {alpha: 1, y: codertxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: tweenDelay});
			tweenDelay += 0.2;
		}

		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: tweenDelay});
		FlxTween.tween(blueballedTxt, {alpha: 1, y: blueballedTxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: tweenDelay + 0.2});

		practiceText = new FlxText(20, 15 + 131, 0, Language.getPhrase("Practice Mode").toUpperCase(), 32);
		practiceText.scrollFactor.set();
		practiceText.setFormat(Paths.font('vcr.ttf'), 32);
		practiceText.x = FlxG.width - (practiceText.width + 20);
		practiceText.updateHitbox();
		practiceText.visible = PlayState.instance.practiceMode;
		add(practiceText);

		var chartingText:FlxText = new FlxText(20, 15 + 101, 0, Language.getPhrase("Charting Mode").toUpperCase(), 32);
		chartingText.scrollFactor.set();
		chartingText.setFormat(Paths.font('vcr.ttf'), 32);
		chartingText.x = FlxG.width - (chartingText.width + 20);
		chartingText.y = FlxG.height - (chartingText.height + 20);
		chartingText.updateHitbox();
		chartingText.visible = PlayState.chartingMode;
		add(chartingText);

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});

		grpMenuShit = new FlxTypedGroup<Alphabet>();
		add(grpMenuShit);

		missingTextBG = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		missingTextBG.scale.set(FlxG.width, FlxG.height);
		missingTextBG.updateHitbox();
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		regenMenu();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		super.create();
	}
	
	function getPauseSong()
	{
		var formattedSongName:String = (songName != null ? Paths.formatToSongPath(songName) : '');
		var formattedPauseMusic:String = Paths.formatToSongPath(ClientPrefs.data.pauseMusic);
		if(formattedSongName == 'none' || (formattedSongName != 'none' && formattedPauseMusic == 'none')) return null;

		return (formattedSongName != '') ? formattedSongName : formattedPauseMusic;
	}

	var holdTime:Float = 0;
	var cantUnpause:Float = 0.1;
	override function update(elapsed:Float)
	{
		cantUnpause -= elapsed;
		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);

		if(controls.BACK)
		{
			close();
			return;
		}

		if(FlxG.keys.justPressed.F5)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			PlayState.nextReloadAll = true;
			MusicBeatState.resetState();
		}

		updateSkipTextStuff();
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		var daSelected:String = menuItems[curSelected];
		switch (daSelected)
		{
			case 'Skip Time':
				if (controls.UI_LEFT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curTime -= 1000;
					holdTime = 0;
				}
				if (controls.UI_RIGHT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curTime += 1000;
					holdTime = 0;
				}

				if(controls.UI_LEFT || controls.UI_RIGHT)
				{
					holdTime += elapsed;
					if(holdTime > 0.5)
					{
						curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1);
					}

					if(curTime >= FlxG.sound.music.length) curTime -= FlxG.sound.music.length;
					else if(curTime < 0) curTime += FlxG.sound.music.length;
					updateSkipTimeText();
				}
		}

		if (controls.ACCEPT && (cantUnpause <= 0 || !controls.controllerMode))
		{
			if (menuItems == difficultyChoices)
			{
				var songLowercase:String = Paths.formatToSongPath(PlayState.SONG.song);
				var poop:String = Highscore.formatSong(songLowercase, curSelected);
				try
				{
					if(menuItems.length - 1 != curSelected && difficultyChoices.contains(daSelected))
					{
						Song.loadFromJson(poop, songLowercase);
						PlayState.storyDifficulty = curSelected;
						MusicBeatState.resetState();
						FlxG.sound.music.volume = 0;
						PlayState.changedDifficulty = true;
						PlayState.chartingMode = false;
						return;
					}
				}
				catch(e:haxe.Exception)
				{
					trace('ERROR! ${e.message}');
	
					var errorStr:String = e.message;
					if(errorStr.startsWith('[lime.utils.Assets] ERROR:')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
					else errorStr += '\n\n' + e.stack;

					missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
					missingText.screenCenter(Y);
					missingText.visible = true;
					missingTextBG.visible = true;
					FlxG.sound.play(Paths.sound('cancelMenu'));

					super.update(elapsed);
					return;
				}


				menuItems = menuItemsOG;
				regenMenu();
			}

			switch (daSelected)
			{
				case "Resume":
					close();
				case 'Change Difficulty':
					menuItems = difficultyChoices;
					deleteSkipTimeText();
					regenMenu();
				case 'Toggle Practice Mode':
					PlayState.instance.practiceMode = !PlayState.instance.practiceMode;
					PlayState.changedDifficulty = true;
					practiceText.visible = PlayState.instance.practiceMode;
				case "Restart Song":
					restartSong();
				case "Leave Charting Mode":
					restartSong();
					PlayState.chartingMode = false;
				case 'Skip Time':
					if(curTime < Conductor.songPosition)
					{
						PlayState.startOnTime = curTime;
						restartSong(true);
					}
					else
					{
						if (curTime != Conductor.songPosition)
						{
							PlayState.instance.clearNotesBefore(curTime);
							PlayState.instance.setSongTime(curTime);
						}
						close();
					}
				case 'End Song':
					close();
					PlayState.instance.notes.clear();
					PlayState.instance.unspawnNotes = [];
					PlayState.instance.endingSong = true;
					PlayState.instance.finishSong(true);
				case 'Toggle Botplay':
					PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
					PlayState.changedDifficulty = true;
					PlayState.instance.botplayTxt.visible = PlayState.instance.cpuControlled;
					PlayState.instance.botplayTxt.alpha = 1;
					PlayState.instance.botplaySine = 0;
				case 'Options':
					PlayState.instance.paused = true; // For lua
					PlayState.instance.vocals.volume = 0;
					PlayState.instance.canResync = false;
					MusicBeatState.switchState(new OptionsState());
					if(ClientPrefs.data.pauseMusic != 'None')
					{
						FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)), pauseMusic.volume);
						FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.8);
						FlxG.sound.music.time = pauseMusic.time;
					}
					OptionsState.onPlayState = true;
				case "Exit to menu":
					#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
					PlayState.deathCounter = 0;
					PlayState.seenCutscene = false;

					PlayState.instance.canResync = false;
					Mods.loadTopMod();
					
					PlayState.changedDifficulty = false;
					PlayState.chartingMode = false;
					FlxG.camera.followLerp = 0;
					
					FlxG.sound.music.stop();
					PlayState.instance.vocals.stop();
					PlayState.instance.opponentVocals.stop();
					FlxTimer.globalManager.clear();
					FlxTween.globalManager.clear();
					
					var ret:Dynamic = PlayState.instance.callOnScripts('onExitSong', null, true);
					
					close();
					
					var checkNoStickers:Bool = false;
					#if MODS_ALLOWED
					if(Mods.currentModDirectory != null && Mods.currentModDirectory != '')
					{
						var modStickersBasePath:String = Paths.mods(Mods.currentModDirectory + '/stickers/');
						var mainConfigPath:String = modStickersBasePath + 'infoStickers.json';
						
						if(sys.FileSystem.exists(mainConfigPath))
						{
							try {
								var configContent:String = sys.io.File.getContent(mainConfigPath);
								var config:Dynamic = haxe.Json.parse(configContent);
								if(config.no_stickers != null && config.no_stickers == true)
									checkNoStickers = true;
							} catch(e:Dynamic) {}
						}
					}
					#end
					
					if(checkNoStickers)
					{
						if(PlayState.isStoryMode)
						{
							MusicBeatState.switchState(new StoryMenuState());
						}
						else
						{
							var stateToReturn:String = PlayState.returnAfterSongState != null ? PlayState.returnAfterSongState : 'FreeplayState';
							PlayState.returnAfterSongState = null;
							
							#if HSCRIPT_ALLOWED
							var hscriptState = backend.HScriptStateLoader.loadStateScript(stateToReturn);
							if(hscriptState != null)
							{
								MusicBeatState.switchState(hscriptState);
							}
							else
							#end
							{
								var stateClass = backend.StateManager.getStateClass(stateToReturn);
								if(stateClass != null)
								{
									var stateInstance = Type.createInstance(stateClass, []);
									MusicBeatState.switchState(stateInstance);
								}
								else
								{
									MusicBeatState.switchState(new FreeplayState());
								}
							}
						}
						FlxG.sound.playMusic(Paths.music('freakyMenu'));
					}
					else
					{
						FlxTransitionableState.skipNextTransIn = true;
						FlxTransitionableState.skipNextTransOut = true;
						
						if(PlayState.isStoryMode)
						{
							var stickerSubState:StickerSubState = new StickerSubState(null, function(sticker) return new StoryMenuState());
							PlayState.instance.openSubState(stickerSubState);
						}
						else 
						{
							var stateToReturn:String = PlayState.returnAfterSongState != null ? PlayState.returnAfterSongState : 'FreeplayState';
							PlayState.returnAfterSongState = null;
							
							var stickerSubState:StickerSubState = new StickerSubState(null, function(sticker) {
								var oldStickers = sticker.grpStickers != null ? sticker.grpStickers.members.copy() : null;
								
								#if HSCRIPT_ALLOWED
								var hscriptState = backend.HScriptStateLoader.loadStateScript(stateToReturn);
								if(hscriptState != null)
								{
									if(Std.isOfType(hscriptState, backend.HScriptState))
									{
										var hstate = cast(hscriptState, backend.HScriptState);
										hstate.oldStickers = oldStickers;
									}
									return hscriptState;
								}
								else
								#end
								{
									var stateClass = backend.StateManager.getStateClass(stateToReturn);
									if(stateClass != null)
									{
										var stateInstance = Type.createInstance(stateClass, []);
										if(Std.isOfType(stateInstance, FreeplayState))
										{
											return new FreeplayState(oldStickers);
										}
										return stateInstance;
									}
									return new FreeplayState(oldStickers);
								}
							});
							PlayState.instance.openSubState(stickerSubState);
						}
					}
				}
		}
	}

	function deleteSkipTimeText()
	{
		if(skipTimeText != null)
		{
			skipTimeText.kill();
			remove(skipTimeText);
			skipTimeText.destroy();
		}
		skipTimeText = null;
		skipTimeTracker = null;
	}

	public static function restartSong(noTrans:Bool = false)
	{
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

		if(noTrans)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		MusicBeatState.resetState();
	}

	override function destroy()
	{
		if(creditRotationTimer != null)
		{
			creditRotationTimer.cancel();
			creditRotationTimer = null;
		}
		if(creditFadeTween != null)
		{
			creditFadeTween.cancel();
			creditFadeTween = null;
		}
		pauseMusic.destroy();
		super.destroy();
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);
		for (num => item in grpMenuShit.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
				if(item == skipTimeTracker)
				{
					curTime = Math.max(0, Conductor.songPosition);
					updateSkipTimeText();
				}
			}
		}
		missingText.visible = false;
		missingTextBG.visible = false;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function regenMenu():Void {
		for (i in 0...grpMenuShit.members.length)
		{
			var obj:Alphabet = grpMenuShit.members[0];
			obj.kill();
			grpMenuShit.remove(obj, true);
			obj.destroy();
		}

		for (num => str in menuItems) {
			var item = new Alphabet(90, 320, Language.getPhrase('pause_$str', str), true);
			item.isMenuItem = true;
			item.targetY = num;
			grpMenuShit.add(item);

			if(str == 'Skip Time')
			{
				skipTimeText = new FlxText(0, 0, 0, '', 64);
				skipTimeText.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				skipTimeText.scrollFactor.set();
				skipTimeText.borderSize = 2;
				skipTimeTracker = item;
				add(skipTimeText);

				updateSkipTextStuff();
				updateSkipTimeText();
			}
		}
		curSelected = 0;
		changeSelection();
	}
	
	function updateSkipTextStuff()
	{
		if(skipTimeText == null || skipTimeTracker == null) return;

		skipTimeText.x = skipTimeTracker.x + skipTimeTracker.width + 60;
		skipTimeText.y = skipTimeTracker.y;
		skipTimeText.visible = (skipTimeTracker.alpha >= 1);
	}

	function startCreditRotation():Void
	{
		if(creditsList.length <= 1 || rotatingCreditText == null) return;
		
		creditRotationTimer = new FlxTimer().start(15.0, function(tmr:FlxTimer)
		{
			creditFadeTween = FlxTween.tween(rotatingCreditText, {alpha: 0.0}, 0.75,
			{
				ease: FlxEase.quartOut,
				onComplete: function(_)
				{
					currentCreditIndex = (currentCreditIndex + 1) % creditsList.length;
					rotatingCreditText.text = creditsList[currentCreditIndex];
					rotatingCreditText.updateHitbox();
					rotatingCreditText.x = FlxG.width - (rotatingCreditText.width + 20);
					
					FlxTween.tween(rotatingCreditText, {alpha: 1.0}, 0.75,
					{
						ease: FlxEase.quartOut,
						onComplete: function(_)
						{
							startCreditRotation();
						}
					});
				}
			});
		});
	}

	function updateSkipTimeText()
		skipTimeText.text = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false) + ' / ' + FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false);
}