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
		if(!DiscordClient.isInitialized)
		{
			DiscordClient.prepare();
		}
		#if MODS_ALLOWED
		DiscordClient.loadModRPC();
		#end
		DiscordClient.changePresence("In the Menus", null);
		#end

		#if MODS_ALLOWED
		var pack:Dynamic = Mods.getPack();
		if (pack != null && pack.name != null)
			lime.app.Application.current.window.title = pack.name;
		else
			lime.app.Application.current.window.title = "Friday Night Funkin': Psych Engine";

		var iconPath:String = Paths.modFolders('pack.png');
		if (sys.FileSystem.exists(iconPath))
		{
			var icon = lime.graphics.Image.fromFile(iconPath);
			lime.app.Application.current.window.setIcon(icon);
		}
		#end

		Conductor.bpm = 102;

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

		if (initialized && !transitioning && skippedIntro)
		{
			if(pressedEnter)
			{
				if(canSkip)
				{
					goToMainMenu();
				}
				else
				{
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

			skippedIntro = true;
		}
	}
}