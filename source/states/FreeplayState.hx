package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import flixel.util.FlxSave;
import backend.StateManager;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;

import openfl.utils.Assets;
import openfl.media.Sound;

import haxe.Json;
import substates.StickerSubState;
import substates.StickerSubState.StickerSprite;

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	var bg:FlxSprite;
	var intendedColor:Int;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	var stickerSubState:StickerSubState;
	var oldStickers:Array<StickerSprite>;

	var previewSound:FlxSound;
	var previewTimer:FlxTimer;
	var currentPreviewSong:Int = -1;
	static final PREVIEW_VOLUME:Float = 0.8;
	static final PREVIEW_DELAY:Float = 1.0;

	public function new(?stickers:Array<StickerSprite>)
	{
		super();
		oldStickers = stickers;
	}

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

	override function create()
	{
		//Paths.clearStoredMemory();
		//Paths.clearUnusedMemory();
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if MODS_ALLOWED
		var currentMode = getCurrentModMode();
		if(currentMode == 'MODS + FNF SONGS' || currentMode == 'ALL MODS' || currentMode == 'DISABLE MODS')
		{
			lime.app.Application.current.window.title = "Friday Night Funkin': Psych Engine";
		}
		#end

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		#if MODS_ALLOWED
		DiscordClient.loadModRPC();
		#end
		DiscordClient.changePresence("In the Menus", null);
		#end

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO SONGS IN THIS MOD, GET OUT RN\n\nMAKE A WEEK IN the Week Editor Menu.\nPress BACK to return to Main Menu. (Hola soy Chris jeje)",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() StateManager.switchState('MainMenuState')));
			return;
		}

		#if MODS_ALLOWED
		var currentMode = getCurrentModMode();
		#end
		
		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			
			#if MODS_ALLOWED
			var shouldSkip = false;
			
			switch(currentMode)
		{
			case 'SINGLE MOD':
				if(Mods.currentModDirectory != '' && leWeek.folder == '')
					shouldSkip = true;
			
			case 'ALL MODS':
				if(leWeek.folder == '')
					shouldSkip = true;
			
			case 'MODS + FNF SONGS':
				shouldSkip = false;
			
			case 'DISABLE MODS':
				if(leWeek.folder != '')
					shouldSkip = true;
		}
			
			if(shouldSkip) continue;
			#end
			
			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		Mods.loadTopMod();

		if(songs.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO SONGS IN THIS MOD, GET OUT RN\n\nMAKE A WEEK IN the Week Editor Menu.\nPress BACK to return to Main Menu. (Hola soy Chris jeje)",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() StateManager.switchState('MainMenuState')));
			return;
		}

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.targetY = i;
			grpSongs.add(songText);

			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			Mods.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			
			// too laggy with a lot of songs, so i had to recode the logic for it
			songText.visible = songText.active = songText.isMenuItem = false;
			icon.visible = icon.active = false;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}
		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);


		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if(curSelected >= songs.length) curSelected = 0;
		if(songs.length > 0)
		{
			bg.color = songs[curSelected].color;
			intendedColor = bg.color;
		}
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		var leText:String = Language.getPhrase("freeplay_tip", "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.");
		bottomString = leText;
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);
		
		player = new MusicPlayer(this);
		add(player);

		previewSound = new FlxSound();
		previewTimer = new FlxTimer();

		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
		{
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
		}
		
		changeSelection();
		updateTexts();
		super.create();

		if(oldStickers != null && oldStickers.length > 0)
		{
			this.persistentUpdate = false;
			this.persistentDraw = true;
			stickerSubState = new StickerSubState(oldStickers, null);
			openSubState(stickerSubState);
		}
		else
		{
			this.persistentUpdate = true;
		}
	}	

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	override function onFocusLost():Void
	{
		super.onFocusLost();
		if (previewSound != null && previewSound.playing && !player.playingMusic)
		{
			previewSound.pause();
		}
	}

	override function onFocus():Void
	{
		super.onFocus();
		if (previewSound != null && !previewSound.playing && !player.playingMusic && currentPreviewSong == curSelected)
		{
			previewSound.resume();
		}
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;

	var stopMusicPlay:Bool = false;
	override function update(elapsed:Float)
	{
		if(WeekData.weeksList.length < 1 || songs.length < 1)
			return;

		if (previewSound != null && previewSound.playing && !player.playingMusic)
		{
			var targetVolume:Float = PREVIEW_VOLUME * FlxG.sound.volume;
			if (Math.abs(previewSound.volume - targetVolume) > 0.01)
			{
				previewSound.volume = targetVolume;
			}
		}

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) //No decimals, add an empty space
			ratingSplit.push('');
		
		while(ratingSplit[1].length < 2) //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';

		var shiftMult:Int = 1;
		if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

		if (!player.playingMusic)
		{
			scoreText.text = Language.getPhrase('personal_best', 'PERSONAL BEST: {1} ({2}%)', [lerpScore, ratingSplit.join('.')]);
			positionHighscore();
			
			if(songs.length > 1)
			{
				if(FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;	
				}
				else if(FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;	
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if(FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_LEFT_P)
		{
			changeDiff(-1);
			_updateSongLastDifficulty();
		}
		else if (controls.UI_RIGHT_P)
		{
			changeDiff(1);
			_updateSongLastDifficulty();
		}
		}

		if (controls.BACK)
		{
			if (player.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();
			}
			else 
			{
				stopPreview();
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				StateManager.switchState('MainMenuState');
			}
		}

		if(FlxG.keys.justPressed.CONTROL && !player.playingMusic)
		{
			stopPreview();
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if(FlxG.keys.justPressed.SPACE)
		{
			stopPreview();
			destroyFreeplayVocals();

			Mods.currentModDirectory = songs[curSelected].folder;
			var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
			try
			{
				Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
			}
			catch(e:haxe.Exception)
			{
				trace('ERROR LOADING PREVIEW: ${e.message}');
				FlxG.sound.play(Paths.sound('cancelMenu'));
				return;
			}
			if (PlayState.SONG != null && PlayState.SONG.needsVoices)
			{
				vocals = new FlxSound();
				try
				{
					var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
					var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
					if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song);
					
					if(loadedVocals != null && loadedVocals.length > 0)
					{
						vocals.loadEmbedded(loadedVocals);
						FlxG.sound.list.add(vocals);
						vocals.persist = vocals.looped = true;
						vocals.volume = 0.8;
						vocals.play();
						vocals.pause();
					}
					else vocals = FlxDestroyUtil.destroy(vocals);
				}
				catch(e:Dynamic)
				{
					vocals = FlxDestroyUtil.destroy(vocals);
				}
				
				opponentVocals = new FlxSound();
				try
				{
					var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
					var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
					
					if(loadedVocals != null && loadedVocals.length > 0)
					{
						opponentVocals.loadEmbedded(loadedVocals);
						FlxG.sound.list.add(opponentVocals);
						opponentVocals.persist = opponentVocals.looped = true;
						opponentVocals.volume = 0.8;
						opponentVocals.play();
						opponentVocals.pause();
					}
					else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
				}
				catch(e:Dynamic)
				{
					opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
				}
			}

			FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
			FlxG.sound.music.pause();
			instPlaying = curSelected;

			player.playingMusic = true;
			player.curTime = 0;
			player.switchPlayMusic();
			player.pauseOrResume(false);
		}
		else if (controls.ACCEPT && !player.playingMusic)
		{
			stopPreview();
			persistentUpdate = false;
			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

			var chartExists = Song.getChart(poop, songLowercase);
			if(chartExists == null)
			{
				var difficultyName:String = Difficulty.getString(curDifficulty);
				var chartPath:String = Paths.json('${songLowercase}/${poop}');
				missingText.text = 'ERROR WHILE LOADING CHART:\n\nSong: ${songs[curSelected].songName}\nDifficulty: $difficultyName\n\nChart file not found!\n\nPath: $chartPath';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));

				updateTexts(elapsed);
				super.update(elapsed);
				return;
			}

		Song.loadFromJson(poop, songLowercase);
		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = curDifficulty;

		trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
		
		@:privateAccess
		if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
		{
			trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
			Paths.freeGraphicsFromMemory();
		}
		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
		#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
		stopMusicPlay = true;

		destroyFreeplayVocals();
		#if (MODS_ALLOWED && DISCORD_ALLOWED)
		DiscordClient.loadModRPC();
		#end
		}
		else if(controls.RESET && !player.playingMusic)
		{
			stopPreview();
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		updateTexts(elapsed);
		super.update(elapsed);
	}
	
	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic || songs.length < 1)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		if (Difficulty.list.length > 1)
			diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
		else
			diffText.text = displayDiff.toUpperCase();

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic || songs.length < 1)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
		_updateSongLastDifficulty();
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var newColor:Int = songs[curSelected].color;
		if(newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpSongs.members)
		{
			var icon:HealthIcon = iconArray[num];
			item.alpha = 0.6;
			icon.alpha = 0.6;
			if (item.targetY == curSelected)
			{
				item.alpha = 1;
				icon.alpha = 1;
			}
		}
		
		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();
		
		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if(savedDiff != null && !Difficulty.list.contains(savedDiff) && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if(lastDiff > -1)
			curDifficulty = lastDiff;
		else if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
	}

	inline private function _updateSongLastDifficulty()
	{
		if(songs.length > 0)
			songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);
	}

	function playPreview()
	{
		if (player.playingMusic || songs.length < 1)
			return;

		stopPreview();

		var targetSong:Int = curSelected;

		new FlxTimer().start(PREVIEW_DELAY, function(tmr:FlxTimer)
		{
			if (targetSong != curSelected || player.playingMusic || songs.length < 1)
				return;

			currentPreviewSong = curSelected;

			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);

			try
			{
				var instSound:Sound = Paths.inst(songLowercase);
				
				if (instSound != null)
				{
					previewSound.loadEmbedded(instSound);
					previewSound.volume = PREVIEW_VOLUME * FlxG.sound.volume;
					previewSound.play();

					previewSound.onComplete = function()
					{
						if (currentPreviewSong == curSelected && !player.playingMusic)
						{
							previewTimer.start(3.0, function(tmr:FlxTimer)
							{
								if (currentPreviewSong == curSelected && !player.playingMusic)
								{
									playPreview();
								}
							});
						}
					};
				}
			}
			catch(e:Dynamic)
			{
			}
		});
	}

	function stopPreview()
	{
		if (previewTimer != null)
		{
			previewTimer.cancel();
		}

		if (previewSound != null && previewSound.playing)
		{
			previewSound.stop();
			previewSound.volume = 0;
		}

		currentPreviewSong = -1;
	}

	private function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		for (i in _lastVisibles)
		{
			grpSongs.members[i].visible = grpSongs.members[i].active = false;
			iconArray[i].visible = iconArray[i].active = false;
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			var item:Alphabet = grpSongs.members[i];
			item.visible = item.active = true;
			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

			var icon:HealthIcon = iconArray[i];
			icon.visible = icon.active = true;
			_lastVisibles.push(i);
		}
	}

	override function destroy():Void
	{
		stopPreview();

		if (previewSound != null)
		{
			previewSound.destroy();
			previewSound = null;
		}

		if (previewTimer != null)
		{
			previewTimer.destroy();
			previewTimer = null;
		}

		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
		{
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			FlxG.sound.music.volume = 1;
		}
	}	
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}