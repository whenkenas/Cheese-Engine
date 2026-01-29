package backend;

import haxe.Json;

typedef SongMeta =
{
    var creditsA:Array<String>;
    var creditsCO:Array<String>;
    var creditsCH:Array<String>;
    var creditsCOD:Array<String>;
    var showAllCredits:Bool;
}

class MetaData
{
    public static function parse(song:String):SongMeta
    {
        var path = "data/" + song + "/metadata.json";

        if (Paths.fileExists(path, TEXT))
        {
            try
            {
                var raw = Paths.getTextFromFile(path);
                return Json.parse(raw);
            }
            catch (e)
            {
                return getDefault();
            }
        }

        return getDefault();
    }

    static function getDefault():SongMeta
    {
        return {
            creditsA: [""],
            creditsCO: [""],
            creditsCH: [""],
            creditsCOD: [""],
            showAllCredits: false
        };
    }
}
