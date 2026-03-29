package substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxTimer;
import flixel.util.FlxSort;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.addons.transition.FlxTransitionableState;
import openfl.display.BitmapData;

import states.MainMenuState;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class StickerSubState extends MusicBeatSubstate
{
	public var grpStickers:FlxTypedGroup<StickerSprite>;
	var targetState:StickerSubState->FlxState;
	var switchingState:Bool = false;
	public static var transitionSprite:StickerTransitionSprite = null;
	var sounds:Array<String> = [];
	var loadingText:FlxText;
	var isWaitingForLoad:Bool = false;

	public function new(?oldStickers:Array<StickerSprite>, ?targetState:StickerSubState->FlxState):Void
	{
		super();
		this.targetState = (targetState == null) ? ((sticker) -> new MainMenuState()) : targetState;

		#if sys
		var soundPath:String = 'assets/shared/sounds/stickersounds/keys/';
		if(sys.FileSystem.exists(soundPath) && sys.FileSystem.isDirectory(soundPath))
		{
			for(file in sys.FileSystem.readDirectory(soundPath))
			{
				if(file.endsWith('.ogg') || file.endsWith('.mp3'))
				{
					var fileName:String = file.substring(0, file.lastIndexOf('.'));
					sounds.push('stickersounds/keys/$fileName');
				}
			}
		}
		#end

		if(sounds.length == 0)
			sounds.push('scrollMenu');

		if(transitionSprite == null)
			transitionSprite = new StickerTransitionSprite();

		grpStickers = new FlxTypedGroup<StickerSprite>();
		add(grpStickers);

		if (oldStickers != null)
		{
			for (sticker in oldStickers)
				grpStickers.add(sticker);
			degenStickers();
		}
		else
		{
			regenStickers();
		}
	}

	public function degenStickers():Void
	{
		if (grpStickers.members == null || grpStickers.members.length == 0)
		{
			switchingState = false;
			close();
			return;
		}

		transitionSprite.insert();
		transitionSprite.setupStickers(grpStickers);

		var totalStickers = grpStickers.members.length;
		var stickersRemoved = 0;

		for (ind => sticker in grpStickers.members)
		{
			new FlxTimer().start(sticker.timing, _ -> {
				if(sticker != null && sticker.exists)
				{
					var daSound:String = FlxG.random.getObject(sounds);
					FlxG.sound.play(Paths.sound(daSound), 0.6);
					
					sticker.visible = false;
				}
				
				stickersRemoved++;

				if (stickersRemoved >= totalStickers)
				{
					switchingState = false;
					FlxTransitionableState.skipNextTransIn = false;
					
					if(grpStickers != null)
					{
						for(s in grpStickers.members)
						{
							if(s != null)
							{
								s.kill();
								s.destroy();
							}
						}
						grpStickers.clear();
					}
					
					close();
				}
			});
		}
	}

	function regenStickers():Void
	{
		transitionSprite.insert();
		if (grpStickers.members.length > 0)
			grpStickers.clear();

		var stickerFiles:Array<StickerData> = [];
		
		#if sys
		var enableFNFStickers:Bool = true;
			var noStickers:Bool = false;
			var modStickersBasePath:String = '';
			
			#if MODS_ALLOWED
			if(Mods.currentModDirectory != null && Mods.currentModDirectory != '')
			{
				modStickersBasePath = Paths.mods(Mods.currentModDirectory + '/stickers/');
				var mainConfigPath:String = modStickersBasePath + 'infoStickers.json';
				
				if(FileSystem.exists(mainConfigPath))
				{
					try {
						var configContent:String = sys.io.File.getContent(mainConfigPath);
						var config:Dynamic = haxe.Json.parse(configContent);
						if(config.enable_fnf_stickers != null)
							enableFNFStickers = config.enable_fnf_stickers;
						if(config.no_stickers != null)
							noStickers = config.no_stickers;
					} catch(e:Dynamic) {}
				}
				
				if(noStickers)
				{
					switchingState = true;
					new FlxTimer().start(0.01, _ -> {
						FlxG.switchState(targetState(this));
					});
					return;
				}
			
			if(FileSystem.exists(modStickersBasePath) && FileSystem.isDirectory(modStickersBasePath))
				{
					var currentSongName:String = null;
					var currentDifficulty:String = null;
					
					if(PlayState.SONG != null && PlayState.SONG.song != null)
					{
						currentSongName = PlayState.SONG.song;
						if(PlayState.storyDifficulty >= 0 && PlayState.storyDifficulty < Difficulty.list.length)
							currentDifficulty = Difficulty.list[PlayState.storyDifficulty];
					}
					
					var songNameVariants:Array<String> = [];
					if(currentSongName != null)
					{
						songNameVariants.push(currentSongName);
						songNameVariants.push(StringTools.replace(currentSongName, '-', ' '));
						songNameVariants.push(StringTools.replace(currentSongName, ' ', '-'));
						songNameVariants.push(currentSongName.toLowerCase());
						songNameVariants.push(StringTools.replace(currentSongName.toLowerCase(), '-', ' '));
						songNameVariants.push(StringTools.replace(currentSongName.toLowerCase(), ' ', '-'));
					}
					
					for(item in FileSystem.readDirectory(modStickersBasePath))
					{
						var itemPath:String = modStickersBasePath + item;
						
						if(item == 'infoStickers.json') continue;
						
						if(FileSystem.isDirectory(itemPath))
						{
							var setScale:Float = 1.0;
							var stickerSongs:Array<String> = [];
							var setConfigPath:String = itemPath + '/stickers.json';
							
							if(FileSystem.exists(setConfigPath))
							{
								try {
									var setConfigContent:String = sys.io.File.getContent(setConfigPath);
									var setConfig:Dynamic = haxe.Json.parse(setConfigContent);
									if(setConfig.scale != null)
										setScale = Std.parseFloat(Std.string(setConfig.scale));
									if(setConfig.stickerSongs != null)
										stickerSongs = cast setConfig.stickerSongs;
								} catch(e:Dynamic) {}
							}
							
							var shouldLoadThisSet:Bool = false;
							
							if(stickerSongs.length == 0)
							{
								shouldLoadThisSet = true;
							}
							else if(currentSongName != null)
							{
								for(songEntry in stickerSongs)
								{
									var entryParts:Array<String> = songEntry.split('-');
									var entrySongName:String = '';
									var entryDifficulty:String = null;
									
									if(entryParts.length > 1)
									{
										var lastPart:String = entryParts[entryParts.length - 1].toLowerCase();
										var knownDifficulties:Array<String> = ['easy', 'normal', 'hard'];
										
										if(knownDifficulties.indexOf(lastPart) != -1)
										{
											entryDifficulty = lastPart;
											entryParts.pop();
											entrySongName = entryParts.join('-');
										}
										else
										{
											entrySongName = songEntry;
										}
									}
									else
									{
										entrySongName = songEntry;
									}
									
									var songMatches:Bool = false;
									for(variant in songNameVariants)
									{
										if(variant.toLowerCase() == entrySongName.toLowerCase() ||
										   StringTools.replace(variant, ' ', '-').toLowerCase() == entrySongName.toLowerCase() ||
										   StringTools.replace(variant, '-', ' ').toLowerCase() == entrySongName.toLowerCase())
										{
											songMatches = true;
											break;
										}
									}
									
									if(songMatches)
									{
										if(entryDifficulty == null || currentDifficulty == null || entryDifficulty.toLowerCase() == currentDifficulty.toLowerCase())
										{
											shouldLoadThisSet = true;
											break;
										}
									}
								}
							}
							
							var isSongNamedFolder:Bool = false;
							if(currentSongName != null)
							{
								for(variant in songNameVariants)
								{
									if(item.toLowerCase() == variant.toLowerCase() ||
									   StringTools.replace(item, ' ', '-').toLowerCase() == variant.toLowerCase() ||
									   StringTools.replace(item, '-', ' ').toLowerCase() == variant.toLowerCase())
									{
										isSongNamedFolder = true;
										break;
									}
								}
							}
							
							if(isSongNamedFolder)
								shouldLoadThisSet = true;
							
							if(shouldLoadThisSet)
							{
								for(file in FileSystem.readDirectory(itemPath))
								{
									if(file.endsWith('.png'))
									{
										var stickerPath:String = 'mods/' + Mods.currentModDirectory + '/stickers/' + item + '/' + file.substring(0, file.length - 4);
										stickerFiles.push({path: stickerPath, scale: setScale});
									}
								}
								
								if(isSongNamedFolder)
									trace('Loaded song-specific folder stickers: $item');
							}
						}
						else if(item.endsWith('.png'))
						{
							var stickerPath:String = 'mods/' + Mods.currentModDirectory + '/stickers/' + item.substring(0, item.length - 4);
							stickerFiles.push({path: stickerPath, scale: 1.0});
						}
					}
				}
		}
		#end
		
		var modHasNoStickers = stickerFiles.length == 0;
		
		if(enableFNFStickers || modHasNoStickers)
		{
			var stickerPath:String = 'assets/shared/images/transitionSwag/stickers-set-1/';
			if(FileSystem.exists(stickerPath) && FileSystem.isDirectory(stickerPath))
			{
				for(file in FileSystem.readDirectory(stickerPath))
				{
					if(file.endsWith('.png'))
						stickerFiles.push({path: file.substring(0, file.length - 4), scale: 1.0});
				}
			}
		}
		#end

		if(stickerFiles.length == 0)
		{
			switchingState = true;
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.switchState(targetState(this));
			return;
		}

		var xPos:Float = -200;
		var yPos:Float = -200;
		
		while (xPos <= FlxG.width + 200)
		{
			var randomStickerData:StickerData = FlxG.random.getObject(stickerFiles);
			var sticky:StickerSprite = new StickerSprite(0, 0, randomStickerData.path, randomStickerData.scale);
			
			if(sticky.graphic == null || sticky.graphic.width <= 1)
			{
				sticky.destroy();
				xPos += 100;
				continue;
			}

			sticky.visible = false;
			sticky.x = xPos;
			sticky.y = yPos;
			xPos += sticky.frameWidth * 0.5;

			if (xPos >= FlxG.width + 200)
			{
				if (yPos <= FlxG.height + 200)
				{
					xPos = -200;
					yPos += FlxG.random.float(70, 120);
				}
			}

			sticky.angle = FlxG.random.int(-60, 70);
			grpStickers.add(sticky);
		}

		FlxG.random.shuffle(grpStickers.members);

		var totalStickers:Int = grpStickers.members.length;
		var lastStickerIndex:Int = totalStickers - 1;

		var lastOne:StickerSprite = grpStickers.members[lastStickerIndex];
		if(lastOne != null)
		{
			lastOne.updateHitbox();
			lastOne.screenCenter();
			lastOne.angle = 0;
		}

		transitionSprite.setupStickers(grpStickers);

		for (ind => sticker in grpStickers.members)
		{
			sticker.timing = FlxMath.remapToRange(ind, 0, totalStickers, 0, 0.9);

			new FlxTimer().start(sticker.timing, _ -> {
				if(grpStickers == null) return;
				
				if(sticker != null)
				{
					var daSound:String = FlxG.random.getObject(sounds);
					FlxG.sound.play(Paths.sound(daSound), 0.6);
					sticker.visible = true;
					
					var frameTimer:Int = (ind == lastStickerIndex ? 2 : FlxG.random.int(0, 2));
					
					new FlxTimer().start((1 / 24) * frameTimer, _ -> {
						if(sticker != null && sticker.exists)
						{
							var baseScale:Float = sticker.stickerScale;
							sticker.scale.x = sticker.scale.y = FlxG.random.float(0.97 * baseScale, 1.02 * baseScale);
							sticker.updateHitbox();
							
							if(ind == lastStickerIndex)
							{
								new FlxTimer().start(0.5, _ -> {
									switchingState = true;
									FlxTransitionableState.skipNextTransIn = true;
									FlxTransitionableState.skipNextTransOut = true;
									
									if(subState != null)
									{
										subStateClosed.addOnce(s -> {
											FlxG.switchState(targetState(this));
										});
									}
									else
									{
										FlxG.switchState(targetState(this));
									}
								});
							}
						}
					});
				}
			});
		}

		grpStickers.sort((ord, a, b) -> {
			return FlxSort.byValues(ord, a.timing, b.timing);
		});
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		transitionSprite?.update(elapsed);
	}

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		transitionSprite?.onResize();
	}

	override public function close():Void
	{
		if (switchingState) return;
		transitionSprite?.clear();
		super.close();
	}

	override public function destroy():Void
	{
		transitionSprite?.clear();
		if (switchingState) return;
		
		if(grpStickers != null)
		{
			grpStickers.clear();
			grpStickers = null;
		}
		sounds = null;
		super.destroy();
	}
}

typedef StickerData = {
	var path:String;
	var scale:Float;
}

class StickerSprite extends FlxSprite
{
	public var timing:Float = 0;
	public var stickerScale:Float = 1.0;

	public function new(x:Float, y:Float, stickerPath:String, scale:Float = 1.0):Void
	{
		super(x, y);
		this.stickerScale = scale;
		
		try
		{
			if(stickerPath.startsWith('mods/'))
			{
				#if sys
				var fullPath = stickerPath + '.png';
				if(FileSystem.exists(fullPath))
				{
					var bmp = BitmapData.fromFile(fullPath);
					if(bmp != null && bmp.width > 1 && bmp.height > 1)
					{
						loadGraphic(bmp);
					}
				}
				#end
			}
			else
			{
				loadGraphic(Paths.image('transitionSwag/stickers-set-1/$stickerPath'));
			}
		}
		catch(e:Dynamic) {}
		
		if(graphic != null)
		{
			setGraphicSize(Std.int(graphic.width * stickerScale), Std.int(graphic.height * stickerScale));
			updateHitbox();
			scrollFactor.set();
			antialiasing = ClientPrefs.data.antialiasing;
		}
	}
}

@:access(flixel.FlxCamera)
class StickerTransitionSprite extends openfl.display.Sprite
{
	public var stickersCamera:FlxCamera;
	public var grpStickers:FlxTypedGroup<StickerSprite>;

	public function new():Void
	{
		super();
		visible = false;
		stickersCamera = new FlxCamera();
		stickersCamera.bgColor = 0x00000000;
		addChild(stickersCamera.flashSprite);
		FlxG.signals.gameResized.add((_, _) -> this.onResize());
		onResize();
	}

	public function update(elapsed:Float):Void
	{
		stickersCamera.visible = visible;
		if (!visible) return;
		grpStickers?.update(elapsed);
		stickersCamera.update(elapsed);

		stickersCamera?.clearDrawStack();
		stickersCamera?.canvas?.graphics.clear();

		grpStickers?.draw();

		stickersCamera.render();
	}

	public function insert():Void
	{
		FlxG.addChildBelowMouse(this, 9999);
		visible = true;
		onResize();
	}

	public function clear():Void
	{
		FlxG.removeChild(this);
		visible = false;
		grpStickers = null;
		stickersCamera?.clearDrawStack();
		stickersCamera?.canvas?.graphics.clear();
	}

	public function onResize():Void
	{
		x = y = 0;
		scaleX = 1;
		scaleY = 1;
		stickersCamera.onResize();
	}

	public function setupStickers(group:FlxTypedGroup<StickerSprite>):Void
	{
		grpStickers = group;
		grpStickers.camera = stickersCamera;
	}
}