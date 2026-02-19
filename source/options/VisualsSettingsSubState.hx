package options;

import objects.Note;
import objects.StrumNote;
import objects.NoteSplash;
import objects.Alphabet;
import flixel.FlxSprite;

class VisualsSettingsSubState extends BaseOptionsMenu
{
	var noteOptionID:Int = -1;
	var notes:FlxTypedGroup<StrumNote>;
	var splashes:FlxTypedGroup<NoteSplash>;
	var holdCovers:FlxTypedGroup<FlxSprite>;
	var noteY:Float = 90;
	var holdAnimTimer:Float = 0;
	var holdAnimState:Int = 0;
	var isPlayingHoldAnim:Bool = false;
	public function new()
	{
		title = Language.getPhrase('visuals_menu', 'Visuals Settings');
		rpcTitle = 'Visuals Settings Menu';

		notes = new FlxTypedGroup<StrumNote>();
		splashes = new FlxTypedGroup<NoteSplash>();
		holdCovers = new FlxTypedGroup<FlxSprite>();
		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.colArray.length) * i, -200, i, 0);
			changeNoteSkin(note);
			notes.add(note);
			
			var splash:NoteSplash = new NoteSplash(0, 0, null);
			splash.inEditor = true;
			splash.babyArrow = note;
			splash.ID = i;
			splash.kill();
			splashes.add(splash);
			
			var holdCover:FlxSprite = new FlxSprite();
			holdCover.frames = Paths.getSparrowAtlas('holdCovers/holdCoverRGB');
			holdCover.animation.addByPrefix('hold', 'holdCoverRGB', 24, true);
			holdCover.animation.addByPrefix('end', 'holdCoverEndRGB', 24, false);
			holdCover.antialiasing = ClientPrefs.data.antialiasing;
			holdCover.visible = false;
			if(Note.globalRgbShaders[i] == null)
				Note.initializeGlobalRGBShader(i);
			holdCover.shader = Note.globalRgbShaders[i].shader;
			holdCovers.add(holdCover);
		}

		var noteSkins:Array<String> = Mods.mergeAllTextsNamed('images/noteSkins/list.txt');
		var autoDetectedSkins:Array<String> = detectNoteSkins();
		for (skin in autoDetectedSkins)
		{
			if (!noteSkins.contains(skin))
				noteSkins.push(skin);
		}
		if(noteSkins.length > 0)
		{
			if(!noteSkins.contains(ClientPrefs.data.noteSkin))
				ClientPrefs.data.noteSkin = ClientPrefs.defaultData.noteSkin;

			noteSkins.insert(0, ClientPrefs.defaultData.noteSkin);
			var option:Option = new Option('Note Skins:',
				"Select your prefered Note skin.",
				'noteSkin',
				STRING,
				noteSkins);
			addOption(option);
			option.onChange = onChangeNoteSkin;
			noteOptionID = optionsArray.length - 1;
		}
		
		var noteSplashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt');
		var autoDetectedSplashes:Array<String> = detectNoteSplashes();
		for (splash in autoDetectedSplashes)
		{
			if (!noteSplashes.contains(splash))
				noteSplashes.push(splash);
		}
		if(noteSplashes.length > 0)
		{
			if(!noteSplashes.contains(ClientPrefs.data.splashSkin))
				ClientPrefs.data.splashSkin = ClientPrefs.defaultData.splashSkin;

			noteSplashes.insert(0, ClientPrefs.defaultData.splashSkin);
			var option:Option = new Option('Note Splashes:',
				"Select your prefered Note Splash variation.",
				'splashSkin',
				STRING,
				noteSplashes);
			addOption(option);
			option.onChange = onChangeSplashSkin;
		}

		var option:Option = new Option('Hold Cover Opacity',
			'How much transparent should the Hold Covers be.',
			'holdCoverAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		option.onChange = playHoldAnimation;

		var option:Option = new Option('Note Splash Opacity',
			'How much transparent should the Note Splashes be.',
			'splashAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		option.onChange = playNoteSplashes;

		var option:Option = new Option('Strumline Background Player:',
			'Give player strumline a semi-transparent background',
			'strumlineBackgroundPlayer',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Strumline Background Opponent:',
			'Give opponent strumline a semi-transparent background',
			'strumlineBackgroundOpponent',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Use Chart/Mod Note Skins',
			"If checked, uses note skins from charts and mods.\nIf unchecked, uses your personal note skin settings.",
			'useChartNoteSkins',
			BOOL);
		addOption(option);

		var option:Option = new Option('Detailed Ranking',
			'Shows detailed note hit statistics.',
			'detailedRanking',
			BOOL);
		addOption(option);

		var option:Option = new Option('Hide HUD',
			'If checked, hides most HUD elements.',
			'hideHud',
			BOOL);
		addOption(option);
		
		var option:Option = new Option('Time Bar:',
			"What should the Time Bar display?",
			'timeBarType',
			STRING,
			['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']);
		addOption(option);

		var option:Option = new Option('Flashing Lights',
			"Uncheck this if you're sensitive to flashing lights!",
			'flashing',
			BOOL);
		addOption(option);

		var option:Option = new Option('Camera Zooms',
			"If unchecked, the camera won't zoom in on a beat hit.",
			'camZooms',
			BOOL);
		addOption(option);

		var option:Option = new Option('Score Text Grow on Hit',
			"If unchecked, disables the Score text growing\neverytime you hit a note.",
			'scoreZoom',
			BOOL);
		addOption(option);

		var option:Option = new Option('Health Bar Opacity',
			'How much transparent should the health bar and icons be.',
			'healthBarAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		
		#if !mobile
		var option:Option = new Option('FPS Counter:',
			'Select FPS Counter mode.\nOff = Hidden, Simple = Basic info, Advanced = Detailed graphs.',
			'fpsMode',
			STRING,
			['Off', 'Simple', 'Advanced']);
		addOption(option);
		option.onChange = onChangeFPSCounter;

		var option:Option = new Option('Debug Background Opacity:',
			'Adjusts FPS Counter background opacity.\n100% = Fully visible, 10% = Nearly invisible, 0% = Completely hidden.',
			'debugBgOpacity',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		option.onChange = onChangeFPSCounter;
		#end
		
		var option:Option = new Option('Pause Music:',
			"What song do you prefer for the Pause Screen?",
			'pauseMusic',
			STRING,
			['None', 'Tea Time', 'Breakfast', 'Breakfast (Pico)']);
		addOption(option);
		option.onChange = onChangePauseMusic;
		
		#if CHECK_FOR_UPDATES
		var option:Option = new Option('Check for Updates',
			'On Release builds, turn this on to check for updates when you start the game.',
			'checkForUpdates',
			BOOL);
		addOption(option);
		#end

		#if DISCORD_ALLOWED
		var option:Option = new Option('Discord Rich Presence',
			"Uncheck this to prevent accidental leaks, it will hide the Application from your \"Playing\" box on Discord",
			'discordRPC',
			BOOL);
		addOption(option);
		#end

		var option:Option = new Option('Combo Stacking',
			"If unchecked, Ratings and Combo won't stack, saving on System Memory and making them easier to read",
			'comboStacking',
			BOOL);
		addOption(option);

		#if (cpp && windows)
		var option:Option = new Option('Window Theme:',
			"Select window color theme.\nPC Theme = Follows your system theme\nWhite = Always light mode\nDark = Always dark mode",
			'windowTheme',
			STRING,
			['PC Theme', 'White', 'Dark']);
		addOption(option);
		option.onChange = onChangeWindowTheme;

		var option:Option = new Option('Window Color:',
			"Select window header color.\nDefault = System theme\nOther options = Custom colors (Windows 11 only)",
			'windowColor',
			STRING,
			['Default', 'Red', 'Orange', 'Yellow', 'Green', 'Cyan', 'Blue', 'Purple', 'Pink', 'Grey']);
		addOption(option);
		option.onChange = onChangeWindowColor;

		var option:Option = new Option('Allow Mod Window Colors',
			"If checked, mods can change the window color.\nIf unchecked, your personal color settings will always be used.",
			'allowModWindowColor',
			BOOL);
		addOption(option);
		option.onChange = onChangeWindowColor;
		#end

		super();
		add(notes);
		add(holdCovers);
		add(splashes);
	}

	var notesShown:Bool = false;
	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		
		switch(curOption.variable)
		{
			case 'noteSkin', 'splashSkin', 'splashAlpha', 'holdCoverAlpha':
				if(!notesShown)
				{
					for (note in notes.members)
					{
						FlxTween.cancelTweensOf(note);
						FlxTween.tween(note, {y: noteY}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
					}
				}
				notesShown = true;
				
				if(curOption.variable != 'holdCoverAlpha')
				{
					isPlayingHoldAnim = false;
					for (note in notes.members)
						note.playAnim('static');
					for (holdCover in holdCovers.members)
						holdCover.visible = false;
				}
				
				if(curOption.variable.startsWith('splash') && Math.abs(notes.members[0].y - noteY) < 25) playNoteSplashes();
				if(curOption.variable == 'holdCoverAlpha' && Math.abs(notes.members[0].y - noteY) < 25) {
					isPlayingHoldAnim = false;
					for (note in notes.members)
						note.playAnim('static');
					for (holdCover in holdCovers.members)
						holdCover.visible = false;
					isPlayingHoldAnim = true;
					holdAnimTimer = 0;
					holdAnimState = 0;
				}

			default:
				if(notesShown) 
				{
					for (note in notes.members)
					{
						FlxTween.cancelTweensOf(note);
						FlxTween.tween(note, {y: -200}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
					}
				}
				notesShown = false;
				isPlayingHoldAnim = false;
				for (holdCover in holdCovers.members)
					holdCover.visible = false;
		}
	}

	var changedMusic:Bool = false;
	function onChangePauseMusic()
	{
		if(ClientPrefs.data.pauseMusic == 'None')
			FlxG.sound.music.volume = 0;
		else
			FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)));

		changedMusic = true;
	}

	function onChangeNoteSkin()
	{
		notes.forEachAlive(function(note:StrumNote) {
			changeNoteSkin(note);
			note.centerOffsets();
			note.centerOrigin();
		});
	}

	function changeNoteSkin(note:StrumNote)
	{
		var skin:String = Note.defaultNoteSkin;
		var customSkin:String = 'noteSkins/NOTE_assets-' + ClientPrefs.data.noteSkin;
		if(Paths.fileExists('images/$customSkin.png', IMAGE))
		{
			skin = customSkin;
		}
		else
		{
			customSkin = 'noteSkins/NOTE_assets-' + ClientPrefs.data.noteSkin.toLowerCase();
			if(Paths.fileExists('images/$customSkin.png', IMAGE))
			{
				skin = customSkin;
			}
			else
			{
				customSkin = skin + Note.getNoteSkinPostfix();
				if(Paths.fileExists('images/$customSkin.png', IMAGE))
				{
					skin = customSkin;
				}
			}
		}

		note.texture = skin;
		note.reloadNote();
		note.playAnim('static');
	}

	function onChangeSplashSkin()
	{
		var skin:String = 'noteSplashes/noteSplashes-' + ClientPrefs.data.splashSkin;
		if(!Paths.fileExists('images/$skin.png', IMAGE))
		{
			skin = 'noteSplashes/noteSplashes-' + ClientPrefs.data.splashSkin.toLowerCase();
			if(!Paths.fileExists('images/$skin.png', IMAGE))
			{
				skin = NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix();
			}
		}
		
		for (splash in splashes)
			splash.loadSplash(skin);

		playNoteSplashes();
	}

	function playHoldAnimation()
	{
	}

	function playNoteSplashes()
	{
		var rand:Int = 0;
		if (splashes.members[0] != null && splashes.members[0].maxAnims > 1)
			rand = FlxG.random.int(0, splashes.members[0].maxAnims - 1);

		for (splash in splashes)
		{
			splash.revive();

			splash.spawnSplashNote(0, 0, splash.ID, null, false);
			if (splash.maxAnims > 1)
				splash.noteData = splash.noteData % Note.colArray.length + (rand * Note.colArray.length);

			var anim:String = splash.playDefaultAnim();
			var conf = splash.config.animations.get(anim);
			var offsets:Array<Float> = [0, 0];

			var minFps:Int = 22;
			var maxFps:Int = 26;
			if (conf != null)
			{
				offsets = conf.offsets;

				minFps = conf.fps[0];
				if (minFps < 0) minFps = 0;

				maxFps = conf.fps[1];
				if (maxFps < 0) maxFps = 0;
			}

			splash.offset.set(10, 10);
			if (offsets != null)
			{
				splash.offset.x += offsets[0];
				splash.offset.y += offsets[1];
			}

			if (splash.animation.curAnim != null)
				splash.animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);
		}
	}

	override function destroy()
	{
		if(changedMusic && !OptionsState.onPlayState) FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
		Note.globalRgbShaders = [];
		super.destroy();
	}

	#if !mobile
	function onChangeFPSCounter()
	{
		ClientPrefs.updateFPSCounter();
	}
	#end

	#if (cpp && windows)
	function onChangeWindowTheme()
	{
		Main.updateWindowTheme();
	}
	
	function onChangeWindowColor()
	{
		Main.updateWindowTheme();
	}
	#end

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if(isPlayingHoldAnim)
		{
			holdAnimTimer += elapsed;
			
			switch(holdAnimState)
			{
				case 0:
					holdAnimTimer = 0;
					holdAnimState = 1;
					
				case 1:
					if(holdAnimTimer >= 1.0)
					{
						for (i in 0...notes.members.length)
						{
							var note = notes.members[i];
							var holdCover = holdCovers.members[i];
							note.playAnim('confirm', true);
							holdCover.visible = true;
							holdCover.animation.play('hold', true);
							holdCover.setPosition(note.x - 105, note.y - 100);
							holdCover.alpha = ClientPrefs.data.holdCoverAlpha;
						}
						holdAnimTimer = 0;
						holdAnimState = 2;
					}
					
				case 2:
					if(holdAnimTimer >= 1.0)
					{
						for (i in 0...holdCovers.members.length)
						{
							var holdCover = holdCovers.members[i];
							var note = notes.members[i];
							holdCover.animation.play('end', true);
							note.playAnim('static');
						}
						holdAnimTimer = 0;
						holdAnimState = 3;
					}
					
				case 3:
					var allFinished:Bool = true;
					for (holdCover in holdCovers.members)
					{
						if(!holdCover.animation.finished)
							allFinished = false;
					}
					if(allFinished)
					{
						for (holdCover in holdCovers.members)
							holdCover.visible = false;
						holdAnimTimer = 0;
						holdAnimState = 4;
					}
					
				case 4:
					if(holdAnimTimer >= 1.0)
					{
						holdAnimTimer = 0;
						holdAnimState = 1;
					}
			}
		}
		
		for (holdCover in holdCovers.members)
			holdCover.alpha = ClientPrefs.data.holdCoverAlpha;
	}

	function detectNoteSkins():Array<String>
	{
		var skins:Array<String> = [];
		#if sys
		var foldersToCheck:Array<String> = [Paths.getSharedPath() + 'images/noteSkins/'];
		for (modFolder in Mods.getModDirectories())
			foldersToCheck.push(Paths.mods(modFolder + '/images/noteSkins/'));
		foldersToCheck.push(Paths.mods('images/noteSkins/'));
		
		for (folder in foldersToCheck)
		{
			if (sys.FileSystem.exists(folder))
			{
				for (file in sys.FileSystem.readDirectory(folder))
				{
					if (file.endsWith('.png') && file.startsWith('NOTE_assets'))
					{
						if (file.startsWith('NOTE_assets-'))
						{
							var skinName:String = file.substring(12, file.length - 4);
							if (!skins.contains(skinName))
								skins.push(skinName);
						}
					}
				}
			}
		}
		#end
		return skins;
	}

	function detectNoteSplashes():Array<String>
	{
		var splashes:Array<String> = [];
		#if sys
		var foldersToCheck:Array<String> = [Paths.getSharedPath() + 'images/noteSplashes/'];
		for (modFolder in Mods.getModDirectories())
			foldersToCheck.push(Paths.mods(modFolder + '/images/noteSplashes/'));
		foldersToCheck.push(Paths.mods('images/noteSplashes/'));
		
		for (folder in foldersToCheck)
		{
			if (sys.FileSystem.exists(folder))
			{
				for (file in sys.FileSystem.readDirectory(folder))
				{
					if (file.endsWith('.png') && file.startsWith('noteSplashes'))
					{
						if (file.startsWith('noteSplashes-'))
						{
							var splashName:String = file.substring(13, file.length - 4);
							if (!splashes.contains(splashName))
								splashes.push(splashName);
						}
					}
				}
			}
		}
		#end
		return splashes;
	}
}