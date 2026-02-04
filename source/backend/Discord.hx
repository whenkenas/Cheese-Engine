package backend;

#if DISCORD_ALLOWED
import Sys.sleep;
import sys.thread.Thread;
import lime.app.Application;

import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;

import flixel.util.FlxStringUtil;

class DiscordClient
{
	public static var isInitialized:Bool = false;
	private inline static final _defaultID:String = "863222024192262205";
	public static var clientID(default, set):String = _defaultID;
	private static var presence:DiscordPresence = new DiscordPresence();
	@:unreflective private static var __thread:Thread;
	private static var _modDefaultImage:String = 'icon';
	private static var currentSongImageKey:String = null;

	public static function check()
	{
		if(ClientPrefs.data.discordRPC) initialize();
		else if(isInitialized) shutdown();
	}
	
	public static function prepare()
	{
		if (!isInitialized && ClientPrefs.data.discordRPC)
			initialize();

		Application.current.window.onClose.add(function() {
			if(isInitialized) {
				Discord.ClearPresence();
				shutdown();
			}
		});
	}

	public dynamic static function shutdown()
	{
		Discord.ClearPresence();
		isInitialized = false;
		Discord.Shutdown();
	}
	
	private static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void
	{
		final user = cast (request[0].username, String);
		final discriminator = cast (request[0].discriminator, String);

		var message = '(Discord) Connected to User ';
		if (discriminator != '0')
			message += '($user#$discriminator)';
		else
			message += '($user)';

		trace(message);
		changePresence();
	}

	private static function onError(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		trace('Discord: Error ($errorCode: ${cast(message, String)})');
	}

	private static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		trace('Discord: Disconnected ($errorCode: ${cast(message, String)})');
	}

	public static function initialize()
	{
		var discordHandlers:DiscordEventHandlers = DiscordEventHandlers.create();
		discordHandlers.ready = cpp.Function.fromStaticFunction(onReady);
		discordHandlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
		discordHandlers.errored = cpp.Function.fromStaticFunction(onError);
		Discord.Initialize(clientID, cpp.RawPointer.addressOf(discordHandlers), 1, null);

		if(!isInitialized) trace("Discord Client initialized");

		if (__thread == null)
		{
			__thread = Thread.create(() ->
			{
				while (true)
				{
					if (isInitialized)
					{
						#if DISCORD_DISABLE_IO_THREAD
						Discord.UpdateConnection();
						#end
						Discord.RunCallbacks();
					}

					Sys.sleep(1.0);
				}
			});
		}
		isInitialized = true;
	}

	public static function changePresence(details:String = 'In the Menus', ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float, ?largeImageKey:String, ?songName:String)
	{
		var startTimestamp:Float = 0;
		if (hasStartTimestamp) startTimestamp = Date.now().getTime();
		if (endTimestamp > 0) endTimestamp = startTimestamp + endTimestamp;

		var finalLargeImageKey:String = _modDefaultImage;
		
		if (songName != null && songName.length > 0)
		{
			finalLargeImageKey = normalizeSongName(songName);
			currentSongImageKey = finalLargeImageKey;
		}
		else if (largeImageKey != null && largeImageKey.length > 0)
		{
			finalLargeImageKey = largeImageKey;
		}
		else if (details == 'In the Menus')
		{
			currentSongImageKey = null;
			finalLargeImageKey = _modDefaultImage;
		}
		else if (currentSongImageKey != null && currentSongImageKey.length > 0)
		{
			finalLargeImageKey = currentSongImageKey;
		}

		presence.state = state;
		presence.details = details;
		presence.smallImageKey = (clientID == _defaultID) ? smallImageKey : null;
		presence.largeImageKey = finalLargeImageKey;
		presence.largeImageText = "Engine Version: " + states.MainMenuState.psychEngineVersion;
		presence.startTimestamp = Std.int(startTimestamp / 1000);
		presence.endTimestamp = Std.int(endTimestamp / 1000);
		updatePresence();
	}

	public static function updatePresence()
	{
		Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence.__presence));
	}
	
	inline public static function resetClientID()
	{
		clientID = _defaultID;
		_modDefaultImage = 'icon';
		currentSongImageKey = null;
	}

	public static function clearSongImageKey()
	{
		currentSongImageKey = null;
	}

	private static function normalizeSongName(name:String):String
	{
		if (name == null || name.length == 0) return '';
		var normalized = name.toLowerCase();
		normalized = StringTools.replace(normalized, ' ', '-');
		normalized = StringTools.replace(normalized, '_', '-');
		return normalized;
	}

	public static function getModName():String
	{
		#if MODS_ALLOWED
		var pack:Dynamic = Mods.getPack();
		if (pack != null && pack.name != null && Mods.currentModDirectory != '')
			return pack.name;
		#end
		return "Friday Night Funkin': Psych Engine";
	}

	private static function set_clientID(newID:String)
	{
		var change:Bool = (clientID != newID);
		clientID = newID;

		if(change && isInitialized)
		{
			shutdown();
			initialize();
			updatePresence();
		}
		return newID;
	}

	#if MODS_ALLOWED
	public static function loadModRPC()
	{
		var pack:Dynamic = Mods.getPack();
		if(pack != null && pack.discordRPC != null && pack.discordRPC != clientID)
		{
			clientID = pack.discordRPC;
		}
		if(pack != null && pack.discordImage != null)
		{
			_modDefaultImage = pack.discordImage;
		}
		else
		{
			_modDefaultImage = 'icon';
		}
		currentSongImageKey = null;
	}
	#end

	#if LUA_ALLOWED
	public static function addLuaCallbacks(lua:State)
	{
		Lua_helper.add_callback(lua, "changeDiscordPresence", changePresence);
		Lua_helper.add_callback(lua, "changeDiscordClientID", function(?newID:String) {
			if(newID == null) newID = _defaultID;
			clientID = newID;
		});
	}
	#end
}

@:allow(backend.DiscordClient)
private final class DiscordPresence
{
	public var state(get, set):String;
	public var details(get, set):String;
	public var smallImageKey(get, set):String;
	public var largeImageKey(get, set):String;
	public var largeImageText(get, set):String;
	public var startTimestamp(get, set):Int;
	public var endTimestamp(get, set):Int;

	@:noCompletion private var __presence:DiscordRichPresence;

	function new()
	{
		__presence = DiscordRichPresence.create();
	}

	public function toString():String
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("state", state),
			LabelValuePair.weak("details", details),
			LabelValuePair.weak("smallImageKey", smallImageKey),
			LabelValuePair.weak("largeImageKey", largeImageKey),
			LabelValuePair.weak("largeImageText", largeImageText),
			LabelValuePair.weak("startTimestamp", startTimestamp),
			LabelValuePair.weak("endTimestamp", endTimestamp)
		]);
	}

	@:noCompletion inline function get_state():String
	{
		return __presence.state;
	}

	@:noCompletion inline function set_state(value:String):String
	{
		return __presence.state = value;
	}

	@:noCompletion inline function get_details():String
	{
		return __presence.details;
	}

	@:noCompletion inline function set_details(value:String):String
	{
		return __presence.details = value;
	}

	@:noCompletion inline function get_smallImageKey():String
	{
		return __presence.smallImageKey;
	}

	@:noCompletion inline function set_smallImageKey(value:String):String
	{
		return __presence.smallImageKey = value;
	}

	@:noCompletion inline function get_largeImageKey():String
	{
		return __presence.largeImageKey;
	}
	
	@:noCompletion inline function set_largeImageKey(value:String):String
	{
		return __presence.largeImageKey = value;
	}

	@:noCompletion inline function get_largeImageText():String
	{
		return __presence.largeImageText;
	}

	@:noCompletion inline function set_largeImageText(value:String):String
	{
		return __presence.largeImageText = value;
	}

	@:noCompletion inline function get_startTimestamp():Int
	{
		return __presence.startTimestamp;
	}

	@:noCompletion inline function set_startTimestamp(value:Int):Int
	{
		return __presence.startTimestamp = value;
	}

	@:noCompletion inline function get_endTimestamp():Int
	{
		return __presence.endTimestamp;
	}

	@:noCompletion inline function set_endTimestamp(value:Int):Int
	{
		return __presence.endTimestamp = value;
	}
}
#end