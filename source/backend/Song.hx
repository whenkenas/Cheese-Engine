package backend;

import haxe.Json;
import lime.utils.Assets;

import objects.Note;

typedef ExtraStrumlineData =
{
	var character:String;
	var type:String;
	var stagePosition:String;
	var scale:Float;
	var spacing:Float;
	var hudX:Float;
	var hudY:Float;
	var visible:Bool;
	var scrollSpeed:Float;
	var usesChartScroll:Bool;
	var useExistingStrumline:Bool;
	@:optional var layer:Int;
}

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var mania:Int;
	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;
	@:optional var disableSplashRGB:Bool;
	@:optional var disableHoldRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
	@:optional var holdCoverSkin:String;

	@:optional var extraStrumlines:Array<ExtraStrumlineData>;
}

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Float;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
	@:optional var mustHitTarget:String;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var holdCoverSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var disableSplashRGB:Bool = false;
	public var disableHoldRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = 'psych_v1';

	public static function convert(songJson:Dynamic) // Convert old charts to psych_v1 format
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		var sectionsData:Array<SwagSection> = songJson.notes;
		if(sectionsData == null) return;

		for (section in sectionsData)
		{
			var beats:Null<Float> = cast section.sectionBeats;
			if (beats == null || Math.isNaN(beats))
			{
				section.sectionBeats = 4;
				if(Reflect.hasField(section, 'lengthInSteps')) Reflect.deleteField(section, 'lengthInSteps');
			}

			for (note in section.sectionNotes)
			{
				if (note[1] >= 8)
				{
					if(!Std.isOfType(note[3], String))
						note[3] = Note.defaultNoteTypes[note[3]];
					continue;
				}
				var gottaHitNote:Bool = (note[1] < 4) ? section.mustHitSection : !section.mustHitSection;
				note[1] = (note[1] % 4) + (gottaHitNote ? 0 : 4);

				if(!Std.isOfType(note[3], String))
					note[3] = Note.defaultNoteTypes[note[3]]; //compatibility with Week 7 and 0.1-0.3 psych charts
			}
		}
	}

	public static var chartPath:String;
	public static var loadedSongName:String;
	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		PlayState.SONG = getChart(jsonInput, folder);
		if(PlayState.SONG == null)
		{
			throw new haxe.Exception('Chart file not found: $jsonInput');
		}
		loadedSongName = folder;
		chartPath = _lastPath;
		#if windows
		// prevent any saving errors by fixing the path on Windows (being the only OS to ever use backslashes instead of forward slashes for paths)
		chartPath = chartPath.replace('/', '\\');
		#end
		StageData.loadDirectory(PlayState.SONG);
		return PlayState.SONG;
	}

		static var _lastPath:String;
	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		var rawData:String = null;
		
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		
		#if MODS_ALLOWED
		var newPath1:String = Paths.json('$formattedFolder/charts/$formattedSong');
		if(FileSystem.exists(newPath1))
		{
			_lastPath = newPath1;
			rawData = File.getContent(_lastPath);
			return rawData != null ? parseJSON(rawData, jsonInput) : null;
		}
		
		var newPath2:String = Paths.json('$formattedFolder/chart/$formattedSong');
		if(FileSystem.exists(newPath2))
		{
			_lastPath = newPath2;
			rawData = File.getContent(_lastPath);
			return rawData != null ? parseJSON(rawData, jsonInput) : null;
		}
		#end
		
		_lastPath = Paths.json('$formattedFolder/$formattedSong');

		#if MODS_ALLOWED
		if(FileSystem.exists(_lastPath))
			rawData = File.getContent(_lastPath);
		else
		#end
		{
			if(Assets.exists(_lastPath))
				rawData = Assets.getText(_lastPath);
			else
				return null;
		}

		return rawData != null ? parseJSON(rawData, jsonInput) : null;
	}

	static function getCodenameMeta(?songName:String):Dynamic
	{
		if(songName == null) return null;

		var formattedFolder:String = Paths.formatToSongPath(songName);
		var possiblePaths:Array<String> = [
			Paths.json('$formattedFolder/meta'),
			Paths.json('$formattedFolder/charts/meta'),
			Paths.json('$formattedFolder/chart/meta')
		];

		var rawMeta:String = null;
		for (metaPath in possiblePaths)
		{
			#if MODS_ALLOWED
			if(FileSystem.exists(metaPath))
			{
				rawMeta = File.getContent(metaPath);
				break;
			}
			#end
			if(Assets.exists(metaPath))
			{
				rawMeta = Assets.getText(metaPath);
				break;
			}
		}

		if(rawMeta == null)
		{
			trace('WARNING: could not find meta.json for codename song $songName.');
			return null;
		}

		return Json.parse(rawMeta);
	}

	static function getCodenameMetaBPM(?songName:String):Float
	{
		var metaJson:Dynamic = getCodenameMeta(songName);
		if(metaJson == null) return 100;

		var bpmField:Dynamic = Reflect.field(metaJson, 'bpm');
		if(bpmField == null)
		{
			trace('WARNING: meta.json for codename song $songName has no bpm field, defaulting to 100.');
			return 100;
		}

		var bpm:Float = bpmField;
		if(Math.isNaN(bpm))
		{
			trace('WARNING: meta.json for codename song $songName has an invalid bpm field, defaulting to 100.');
			return 100;
		}
		return bpm;
	}

	static function resolveCodenameNoteType(noteTypes:Array<String>, rawTypeId:Dynamic):String
	{
		var typeId:Null<Int> = rawTypeId;
		if(typeId == null || typeId <= 0) return '';
		return (noteTypes[typeId - 1] != null) ? noteTypes[typeId - 1] : '';
	}

	static function convertCodenameChart(songJson:Dynamic, ?nameForError:String):Void
	{
		var metaJson:Dynamic = getCodenameMeta(nameForError);

		if(songJson.bpm == null)
		{
			var bpmField:Dynamic = (metaJson != null) ? Reflect.field(metaJson, 'bpm') : null;
			songJson.bpm = (bpmField != null && !Math.isNaN(bpmField)) ? bpmField : 100;
		}

		songJson.song = nameForError;
		songJson.needsVoices = (metaJson != null && Reflect.hasField(metaJson, 'needsVoices')) ? Reflect.field(metaJson, 'needsVoices') : true;
		songJson.speed = (songJson.scrollSpeed != null) ? songJson.scrollSpeed : 1;

		var strumLines:Array<Dynamic> = (songJson.strumLines != null) ? songJson.strumLines : [];
		var noteTypes:Array<String> = (songJson.noteTypes != null) ? songJson.noteTypes : [];

		var playerLine:Dynamic = null;
		var opponentLine:Dynamic = null;
		var extraLines:Array<Dynamic> = [];

		for (line in strumLines)
		{
			if(playerLine == null && line.type == 1)
				playerLine = line;
			else if(opponentLine == null && line.type == 0)
				opponentLine = line;
			else
				extraLines.push(line);
		}

		songJson.player1 = (opponentLine != null) ? opponentLine.characters[0] : 'dad';
		songJson.player2 = (playerLine != null) ? playerLine.characters[0] : 'bf';

		var gfLine:Dynamic = null;
		var finalExtraLines:Array<Dynamic> = [];
		for (line in extraLines)
		{
			if(gfLine == null && line.position == 'gf')
				gfLine = line;
			else
				finalExtraLines.push(line);
		}
		songJson.gfVersion = (gfLine != null) ? gfLine.characters[0] : 'gf';

		var allNotes:Array<Dynamic> = [];

		function pushLineNotes(line:Dynamic, roleOffset:Int):Void
		{
			var keyCount:Int = (line.keyCount != null) ? line.keyCount : 4;
			for (note in (line.notes : Array<Dynamic>))
			{
				allNotes.push([
					note.time,
					note.id + (roleOffset * keyCount),
					(note.sLen != null) ? note.sLen : 0,
					resolveCodenameNoteType(noteTypes, note.type)
				]);
			}
		}

		if(playerLine != null) pushLineNotes(playerLine, 0);
		if(opponentLine != null) pushLineNotes(opponentLine, 1);

		var extraStrumlines:Array<ExtraStrumlineData> = [];
		var extraIndex:Int = 2;
		for (line in finalExtraLines)
		{
			pushLineNotes(line, extraIndex);

			extraStrumlines.push({
				character: line.characters[0],
				type: line.position,
				stagePosition: line.position,
				scale: (line.strumScale != null) ? line.strumScale : 1,
				spacing: (line.strumSpacing != null) ? line.strumSpacing : 1,
				hudX: (line.strumPos != null) ? line.strumPos[0] : 0,
				hudY: (line.strumPos != null) ? line.strumPos[1] : 0,
				visible: (line.visible != null) ? line.visible : true,
				scrollSpeed: (line.scrollSpeed != null) ? line.scrollSpeed : songJson.speed,
				usesChartScroll: line.scrollSpeed != null,
				useExistingStrumline: false,
				layer: extraIndex
			});
			extraIndex++;
		}
		if(extraStrumlines.length > 0) songJson.extraStrumlines = extraStrumlines;

		allNotes.sort(function(a, b) return (a[0] < b[0]) ? -1 : ((a[0] > b[0]) ? 1 : 0));

		var bpmChanges:Array<Dynamic> = [];
		for (event in (songJson.events : Array<Dynamic>))
		{
			if(event.name == 'BPM Change')
				bpmChanges.push({time: event.time, bpm: event.params[0]});
		}
		bpmChanges.sort(function(a, b) return (a.time < b.time) ? -1 : ((a.time > b.time) ? 1 : 0));

		var sections:Array<SwagSection> = [];
		var curBpm:Float = songJson.bpm;
		var curTime:Float = 0;
		var bpmIndex:Int = 0;
		var noteIndex:Int = 0;
		var lastNoteTime:Float = (allNotes.length > 0) ? allNotes[allNotes.length - 1][0] : 0;

		while (noteIndex < allNotes.length || curTime <= lastNoteTime)
		{
			while(bpmIndex < bpmChanges.length && bpmChanges[bpmIndex].time <= curTime)
			{
				curBpm = bpmChanges[bpmIndex].bpm;
				bpmIndex++;
			}

			var sectionLength:Float = (60000 / curBpm) * 4;
			var sectionEnd:Float = curTime + sectionLength;

			var sectionNotes:Array<Dynamic> = [];
			while(noteIndex < allNotes.length && allNotes[noteIndex][0] < sectionEnd)
			{
				sectionNotes.push(allNotes[noteIndex]);
				noteIndex++;
			}

			sections.push({
				sectionNotes: sectionNotes,
				sectionBeats: 4,
				mustHitSection: true,
				bpm: curBpm,
				changeBPM: bpmIndex > 0
			});

			curTime = sectionEnd;
			if(sections.length > 100000) break;
		}

		songJson.notes = sections;
		songJson.events = backend.CodenameEventCompat.convert(songJson.events);

		Reflect.setField(songJson, 'codenameChart', false);
	}

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var songJson:SwagSong = cast Json.parse(rawData);
		if(Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if(subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if(!Reflect.hasField(songJson, 'notes') && Reflect.field(songJson, 'codenameChart') != true && !Reflect.hasField(songJson, 'strumLines') && !Reflect.hasField(songJson, 'events'))
		{
			throw new haxe.Exception('The selected file is not a valid chart (it looks like a meta.json or another file, not a difficulty chart).');
		}

		if(Reflect.field(songJson, 'codenameChart') == true)
		{
			songJson.format = 'codename_convert';
			convertCodenameChart(songJson, nameForError);
			return songJson;
		}

		if(convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if(fmt == null) fmt = songJson.format = 'unknown';

			switch(convertTo)
			{
				case 'psych_v1':
					if(!fmt.startsWith('psych_v1')) //Convert to Psych 1.0 format
					{
						trace('converting chart $nameForError with format $fmt to psych_v1 format...');
						songJson.format = 'psych_v1_convert';
						convert(songJson);
					}
			}
		}
		return songJson;
	}
}