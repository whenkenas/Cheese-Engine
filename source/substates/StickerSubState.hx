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

		grpStickers = new FlxTypedGroup<StickerSprite>();
		add(grpStickers);
		
		var uiCamera:FlxCamera = null;
		for(cam in FlxG.cameras.list)
		{
			if(cam != null)
				uiCamera = cam;
		}
		if(uiCamera != null)
			grpStickers.cameras = [uiCamera];

		if (oldStickers != null)
		{
			for (sticker in oldStickers)
			{
				if(sticker != null && uiCamera != null)
					sticker.cameras = [uiCamera];
				grpStickers.add(sticker);
			}
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
		if (grpStickers.members.length > 0)
			grpStickers.clear();

		var stickerFiles:Array<StickerData> = [];
		
		#if sys
		var enableFNFStickers:Bool = true;
		var modStickersBasePath:String = '';
		
		#if MODS_ALLOWED
		if(Mods.currentModDirectory != null && Mods.currentModDirectory != '')
		{
			modStickersBasePath = Paths.mods(Mods.currentModDirectory + '/stickers/');
			var mainConfigPath:String = modStickersBasePath + 'stickers.json';
			
			if(FileSystem.exists(mainConfigPath))
			{
				try {
					var configContent:String = sys.io.File.getContent(mainConfigPath);
					var config:Dynamic = haxe.Json.parse(configContent);
					if(config.enable_fnf_stickers != null)
						enableFNFStickers = config.enable_fnf_stickers;
				} catch(e:Dynamic) {}
			}
			
			if(FileSystem.exists(modStickersBasePath) && FileSystem.isDirectory(modStickersBasePath))
			{
				var songName:String = null;
			var useSongStickers:Bool = false;
			
			if(PlayState.SONG != null && PlayState.SONG.song != null)
			{
				songName = PlayState.SONG.song;
				var songStickerPath1:String = modStickersBasePath + songName + '/';
				var songStickerPath2:String = modStickersBasePath + StringTools.replace(songName, '-', ' ') + '/';
				var songStickerPath3:String = modStickersBasePath + StringTools.replace(songName, ' ', '-') + '/';
				
				var songStickerPath:String = null;
				if(FileSystem.exists(songStickerPath1) && FileSystem.isDirectory(songStickerPath1))
					songStickerPath = songStickerPath1;
				else if(FileSystem.exists(songStickerPath2) && FileSystem.isDirectory(songStickerPath2))
					songStickerPath = songStickerPath2;
				else if(FileSystem.exists(songStickerPath3) && FileSystem.isDirectory(songStickerPath3))
					songStickerPath = songStickerPath3;
				
				if(songStickerPath != null)
				{
					useSongStickers = true;
					var setScale:Float = 1.0;
					var setConfigPath:String = songStickerPath + 'stickers.json';
					
					if(FileSystem.exists(setConfigPath))
					{
						try {
							var setConfigContent:String = sys.io.File.getContent(setConfigPath);
							var setConfig:Dynamic = haxe.Json.parse(setConfigContent);
							if(setConfig.scale != null)
								setScale = Std.parseFloat(Std.string(setConfig.scale));
						} catch(e:Dynamic) {}
					}
					
					for(file in FileSystem.readDirectory(songStickerPath))
					{
						if(file.endsWith('.png'))
						{
							var folderName:String = songStickerPath.substring(modStickersBasePath.length);
							folderName = folderName.substring(0, folderName.length - 1);
							var stickerPath:String = 'mods/' + Mods.currentModDirectory + '/stickers/' + folderName + '/' + file.substring(0, file.length - 4);
							stickerFiles.push({path: stickerPath, scale: setScale});
						}
					}
					
					trace('Loaded ${stickerFiles.length} song-specific stickers for: $songName');
				}
			}
			
			if(!useSongStickers && FileSystem.exists(modStickersBasePath) && FileSystem.isDirectory(modStickersBasePath))
			{
				for(item in FileSystem.readDirectory(modStickersBasePath))
				{
					var itemPath:String = modStickersBasePath + item;
					
					if(FileSystem.isDirectory(itemPath))
					{
						var setScale:Float = 1.0;
						var setConfigPath:String = itemPath + '/stickers.json';
						
						if(FileSystem.exists(setConfigPath))
						{
							try {
								var setConfigContent:String = sys.io.File.getContent(setConfigPath);
								var setConfig:Dynamic = haxe.Json.parse(setConfigContent);
								if(setConfig.scale != null)
									setScale = Std.parseFloat(Std.string(setConfig.scale));
							} catch(e:Dynamic) {}
						}
						
						for(file in FileSystem.readDirectory(itemPath))
						{
							if(file.endsWith('.png'))
							{
								var stickerPath:String = 'mods/' + Mods.currentModDirectory + '/stickers/' + item + '/' + file.substring(0, file.length - 4);
								stickerFiles.push({path: stickerPath, scale: setScale});
							}
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

		var xPos:Float = -100;
		var yPos:Float = -100;
		
		while (xPos <= FlxG.width)
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

			if (xPos >= FlxG.width)
			{
				if (yPos <= FlxG.height)
				{
					xPos = -100;
					yPos += FlxG.random.float(70, 120);
				}
			}

			sticky.angle = FlxG.random.int(-60, 70);
			
			var uiCamera:FlxCamera = null;
			for(cam in FlxG.cameras.list)
			{
				if(cam != null)
					uiCamera = cam;
			}
			if(uiCamera != null)
				sticky.cameras = [uiCamera];
			
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
	}

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		
		if(grpStickers != null)
		{
			for(sticker in grpStickers.members)
			{
				if(sticker != null && sticker.exists)
				{
					var uiCamera:FlxCamera = null;
					for(cam in FlxG.cameras.list)
					{
						if(cam != null)
							uiCamera = cam;
					}
					if(uiCamera != null)
						sticker.cameras = [uiCamera];
				}
			}
		}
	}

	override public function close():Void
	{
		if (switchingState) return;
		super.close();
	}

	override public function destroy():Void
	{
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