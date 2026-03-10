package debug;

#if cpp
import cpp.Lib;
#end

#if (cpp && windows)
@:cppFileCode('
#include <windows.h>
static WNDPROC originalConsoleProc = NULL;
static LRESULT CALLBACK ConsoleWindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    if (uMsg == WM_CLOSE) {
        FreeConsole();
        return 0;
    }
    return CallWindowProc(originalConsoleProc, hwnd, uMsg, wParam, lParam);
}
')
#end
class CMD {
    static var consoleOpened:Bool = false;
    
    public static function openCMD():Void{
        #if windows
        if (consoleOpened) return;
        
        untyped __cpp__('AllocConsole()');
        untyped __cpp__('SetConsoleTitle("Debug Console")');
        untyped __cpp__('HWND consoleWindow = GetConsoleWindow()');
        untyped __cpp__('originalConsoleProc = (WNDPROC)SetWindowLongPtr(consoleWindow, GWLP_WNDPROC, (LONG_PTR)ConsoleWindowProc)');
        untyped __cpp__('SetForegroundWindow(consoleWindow)');

        untyped __cpp__('freopen("CONOUT$", "w", stdout)');
        untyped __cpp__('freopen("CONOUT$", "w", stderr)');

        haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos) {
            var msg = infos.fileName + ":" + infos.lineNumber + ": " + v;
            Sys.println(msg); 
        };
        
        consoleOpened = true;
        trace("cmdopened");
        #end
    }
}