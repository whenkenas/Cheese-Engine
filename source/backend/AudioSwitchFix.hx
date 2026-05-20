package backend;

import flixel.FlxState;
import flixel.sound.FlxSound;
import backend.Native;
import lime.media.AudioManager;
import lime.media.AudioSource;
import lime._internal.backend.native.NativeAudioSource;
import haxe.Timer;

@:dox(hide)
class AudioSwitchFix {
	public static function onAudioDisconnected() @:privateAccess {
		NativeAudioSource.audioDisconnected = true;

		var sources:Array<{source:AudioSource, playing:Bool, time:Float, gain:Float, pitch:Float, position:lime.math.Vector4}> = [];
		for (source in AudioSource.activeSources) {
			var wasPlaying = source.playing;
			sources.push({
				source: source,
				playing: wasPlaying,
				time: wasPlaying ? source.__backend.lastKnownTime : source.currentTime,
				gain: source.gain,
				pitch: source.pitch,
				position: source.position
			});

			source.__backend.dispose();
			if (wasPlaying) source.__backend.playing = true;
		}

		AudioManager.shutdown();
		AudioManager.init();

		for (d in sources) {
			d.source.__backend.init();
			d.source.currentTime = d.time;
			d.source.gain = d.gain;
			d.source.pitch = d.pitch;
			d.source.position = d.position;

			if (d.playing) d.source.play();
		}

		NativeAudioSource.audioDisconnected = false;
		Main.changeID++;
		Main.audioDisconnected = false;
	}

	private static var timer:Timer;

	private static function onRun() if (Main.audioDisconnected) onAudioDisconnected();
	public static function init() {
		Native.registerAudio();
		if (timer == null) (timer = new Timer(1000)).run = onRun;
	}
}