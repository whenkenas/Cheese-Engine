package backend;

class MemoryUtils
{
	public static function supportsTaskMem():Bool
	{
		#if ((cpp && (windows || ios || macos)) || linux || android)
		return true;
		#else
		return false;
		#end
	}

	public static function getTaskMemory():Float
	{
		#if (windows && cpp)
		return getWindowsTaskMemory();
		#elseif (linux || android)
		return getLinuxTaskMemory();
		#end

		return 0.0;
	}

	#if (windows && cpp)
	public static function getWindowsTaskMemory():Float
	{
		return openfl.system.System.totalMemory;
	}
	#end

	#if (linux || android)
	public static function getLinuxTaskMemory():Float
	{
		try
		{
			#if cpp
			final input:sys.io.FileInput = sys.io.File.read('/proc/${cpp.NativeSys.sys_get_pid()}/status', false);
			#else
			final input:sys.io.FileInput = sys.io.File.read('/proc/self/status', false);
			#end

			final regex:EReg = ~/^VmRSS:\s+(\d+)\s+kB/m;
			var line:String;
			do
			{
				if (input.eof())
				{
					input.close();
					return 0.0;
				}
				line = input.readLine();
			}
			while (!regex.match(line));

			input.close();

			final kb:Float = Std.parseFloat(regex.matched(1));

			if (kb != Math.NaN)
			{
				return kb * 1024.0;
			}
		}
		catch (e:Dynamic) {}

		return 0.0;
	}
	#end

	public static function getGCMemory():Float
	{
		#if cpp
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		#else
		return openfl.system.System.totalMemory;
		#end
	}
}