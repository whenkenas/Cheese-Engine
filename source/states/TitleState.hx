package states;

import backend.WeekData;
import flixel.input.keyboard.FlxKey;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import haxe.Json;
import openfl.Assets;
import states.StoryMenuState;
import states.MainMenuState;
import backend.StateManager;
import flixel.graphics.frames.FlxFrame;

class TitleState extends MusicBeatState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];
	public static var initialized:Bool = false;

	var credGroup:FlxGroup = new FlxGroup();
	var textGroup:FlxGroup = new FlxGroup();
	var blackScreen:FlxSprite;
	var credTextShit:Alphabet;
	var ngSpr:FlxSprite;

	var curWacky:Array<String> = [];
	
	var bg:FlxSprite;
	var logo:FlxSprite;
	var text:FlxSprite;
	var expansion:FlxSprite;
	var box:FlxSprite;
	var isSingleMod:Bool = false;
	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var newTitle:Bool = false;
	var titleTimer:Float = 0;
	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	override public function create():Void
	{
		Paths.clearStoredMemory();
		super.create();
		Paths.clearUnusedMemory();

		if(!initialized)
		{
			ClientPrefs.loadPrefs();
			Language.reloadPhrases();
		}

		curWacky = FlxG.random.getObject(getIntroTextShit());

		if(!initialized)
		{
			if(FlxG.save.data != null && FlxG.save.data.fullscreen)
			{
				FlxG.fullscreen = FlxG.save.data.fullscreen;
			}
			persistentUpdate = true;
			persistentDraw = true;
		}

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		FlxG.mouse.visible = false;
		#if FREEPLAY
		MusicBeatState.switchState(new FreeplayState());
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#else
		if(FlxG.save.data.flashing == null && !FlashingState.leftState)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
		}
		else
			startIntro();
		#end
	}

	function startIntro()
	{
		persistentUpdate = true;
		if (!initialized && FlxG.sound.music == null)
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);

		#if DISCORD_ALLOWED
		#if MODS_ALLOWED
		DiscordClient.loadModRPC();
		#end
		if(!DiscordClient.isInitialized)
		{
			DiscordClient.prepare();
		}
		DiscordClient.changePresence("In the Menus", null);
		#end

		#if MODS_ALLOWED
		var modSave:flixel.util.FlxSave = new flixel.util.FlxSave();
		modSave.bind('funkin', CoolUtil.getSavePath());
		if(modSave != null && modSave.data != null && modSave.data.modMode != null)
			isSingleMod = (modSave.data.modMode == 'SINGLE MOD');
		else
			isSingleMod = (Mods.currentModDirectory != null && Mods.currentModDirectory != '');

		if(isSingleMod)
		{
			var pack:Dynamic = Mods.getPack();
			if(pack != null && pack.name != null)
				lime.app.Application.current.window.title = pack.name;
			else
				lime.app.Application.current.window.title = "Friday Night Funkin': Psych Engine";

			var iconPath:String = Paths.modFolders('pack.png');
			if(sys.FileSystem.exists(iconPath))
			{
				var icon = lime.graphics.Image.fromFile(iconPath);
				lime.app.Application.current.window.setIcon(icon);
			}
		}
		else
		{
			lime.app.Application.current.window.title = "Friday Night Funkin': Psych Engine";
		}
		#end

		Conductor.bpm = 102;

		if(isSingleMod)
		{
			logoBl = new FlxSprite(-150, -100);
			logoBl.frames = Paths.getSparrowAtlas('logoBumpin');
			logoBl.antialiasing = ClientPrefs.data.antialiasing;
			logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
			logoBl.animation.play('bump');
			logoBl.updateHitbox();

			gfDance = new FlxSprite(512, 40);
			gfDance.antialiasing = ClientPrefs.data.antialiasing;
			gfDance.frames = Paths.getSparrowAtlas('gfDanceTitle');
			gfDance.animation.addByIndices('danceLeft', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
			gfDance.animation.addByIndices('danceRight', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
			gfDance.animation.play('danceRight');

			var animFrames:Array<FlxFrame> = [];
			titleText = new FlxSprite(100, 576);
			titleText.frames = Paths.getSparrowAtlas('titleEnter');
			@:privateAccess
			{
				titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
				titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
			}

			if (newTitle = animFrames.length > 0)
			{
				titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
				titleText.animation.addByPrefix('press', ClientPrefs.data.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
			}
			else
			{
				titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
				titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
			}
			titleText.animation.play('idle');
			titleText.updateHitbox();

			add(gfDance);
			add(logoBl);
			add(titleText);
		}

		blackScreen = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		blackScreen.scale.set(FlxG.width, FlxG.height);
		blackScreen.updateHitbox();
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();
		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = ClientPrefs.data.antialiasing;

		add(credGroup);
		add(ngSpr);

		if (initialized)
			skipIntro();
		else
			initialized = true;
	}

	function getIntroTextShit():Array<Array<String>>
	{
		#if MODS_ALLOWED
		var firstArray:Array<String> = Mods.mergeAllTextsNamed('data/introText.txt');
		#else
		var fullText:String = Assets.getText(Paths.txt('introText'));
		var firstArray:Array<String> = fullText.split('\n');
		#end
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;
	var canSkip:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}

		if(isSingleMod && newTitle)
		{
			titleTimer += FlxMath.bound(elapsed, 0, 1);
			if(titleTimer > 2) titleTimer -= 2;
		}

		if (initialized && !transitioning && skippedIntro)
		{
			if(isSingleMod && newTitle && !canSkip && titleText != null)
			{
				var timer:Float = titleTimer;
				if(timer >= 1)
					timer = (-timer) + 2;
				timer = FlxEase.quadInOut(timer);
				titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
				titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
			}

			if(pressedEnter)
			{
				if(canSkip)
				{
					goToMainMenu();
				}
				else
				{
					if(isSingleMod && titleText != null)
					{
						titleText.color = FlxColor.WHITE;
						titleText.alpha = 1;
						titleText.animation.play('press');
					}

					FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
					FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);
					canSkip = true;
					
					new FlxTimer().start(1, function(tmr:FlxTimer)
					{
						goToMainMenu();
					});
				}
			}
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		super.update(elapsed);
	}
	
	function goToMainMenu()
	{
		if(!transitioning)
		{
			transitioning = true;
			StateManager.switchState('MainMenuState');
			closedState = true;
		}
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if(credGroup != null && textGroup != null)
			{
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if(textGroup != null && credGroup != null) {
			var coolText:Alphabet = new Alphabet(0, 0, text, true);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			credGroup.add(coolText);
			textGroup.add(coolText);
		}
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var sickBeats:Int = 0;
	public static var closedState:Bool = false;
	override function beatHit()
	{
		super.beatHit();

		if(logoBl != null)
			logoBl.animation.play('bump', true);

		if(gfDance != null)
		{
			danceLeft = !danceLeft;
			if(danceLeft)
				gfDance.animation.play('danceRight');
			else
				gfDance.animation.play('danceLeft');
		}

		if(!closedState)
		{
			sickBeats++;
			switch (sickBeats)
			{
				case 1:
					FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
					FlxG.sound.music.fadeIn(4, 0, 0.7);
				case 2:
					createCoolText(['Psych Engine by'], 40);
				case 4:
					addMoreText('Shadow Mario', 40);
					addMoreText('Riveren', 40);
				case 5:
					deleteCoolText();
				case 6:
					createCoolText(['Not associated', 'with'], -40);
				case 8:
					addMoreText('newgrounds', -40);
					ngSpr.visible = true;
				case 9:
					deleteCoolText();
					ngSpr.visible = false;
				case 10:
					createCoolText([curWacky[0]]);
				case 12:
					addMoreText(curWacky[1]);
				case 13:
					deleteCoolText();
				case 14:
					addMoreText('Friday');
				case 15:
					addMoreText('Night');
				case 16:
					addMoreText('Funkin');
				case 17:
					skipIntro();
			}
		}
	}

	var skippedIntro:Bool = false;
	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			remove(ngSpr);
			remove(credGroup);
			FlxG.camera.flash(FlxColor.WHITE, 4);

			if(isSingleMod)
			{
				if(gfDance != null) remove(gfDance);
				if(logoBl != null) remove(logoBl);
				if(titleText != null) remove(titleText);

				if(gfDance != null) add(gfDance);
				if(logoBl != null) add(logoBl);
				if(titleText != null) add(titleText);
			}
			else
			{
				bg = new FlxSprite(0, 0).loadGraphic(Paths.image('TitleMenu/bg'));
				bg.antialiasing = false;
				bg.setGraphicSize(FlxG.width, FlxG.height);
				bg.updateHitbox();
				add(bg);

				logo = new FlxSprite(0, 0).loadGraphic(Paths.image('TitleMenu/logo'));
				logo.antialiasing = false;
				logo.setGraphicSize(FlxG.width, FlxG.height);
				logo.updateHitbox();
				add(logo);
				FlxTween.tween(logo, {y: logo.y - 15}, 3, {ease: FlxEase.sineInOut, type: PINGPONG});

				text = new FlxSprite(0, 0).loadGraphic(Paths.image('TitleMenu/text'));
				text.antialiasing = false;
				text.setGraphicSize(FlxG.width, FlxG.height);
				text.updateHitbox();
				add(text);
				FlxTween.tween(text, {y: text.y - 15}, 3, {ease: FlxEase.sineInOut, type: PINGPONG});

				expansion = new FlxSprite(0, 0).loadGraphic(Paths.image('TitleMenu/expansion'));
				expansion.antialiasing = false;
				expansion.setGraphicSize(FlxG.width, FlxG.height);
				expansion.updateHitbox();
				add(expansion);
				FlxTween.tween(expansion, {y: expansion.y - 15}, 3, {ease: FlxEase.sineInOut, type: PINGPONG});

				box = new FlxSprite(0, 0).loadGraphic(Paths.image('TitleMenu/box'));
				box.antialiasing = false;
				box.setGraphicSize(FlxG.width, FlxG.height);
				box.updateHitbox();
				add(box);
			}

			skippedIntro = true;
		}
	}
}