package backend;

import haxe.Json;

typedef CreditEntry = {
    var role:String;
    var names:Array<String>;
}

typedef SongMeta =
{
    var credits:Array<CreditEntry>;
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
                var jsonData:Dynamic = Json.parse(raw);
                
                var credits:Array<CreditEntry> = [];
                
                if(Reflect.hasField(jsonData, 'credits'))
                {
                    var creditsObj:Dynamic = Reflect.field(jsonData, 'credits');
                    
                    var creditsStart:Int = raw.indexOf('"credits"');
                    if(creditsStart != -1)
                    {
                        var braceStart:Int = raw.indexOf('{', creditsStart);
                        var braceEnd:Int = findMatchingBrace(raw, braceStart);
                        var creditsRaw:String = raw.substring(braceStart + 1, braceEnd);
                        
                        var orderPattern:EReg = ~/"([^"]+)"\s*:/g;
                        var orderedFields:Array<String> = [];
                        
                        while(orderPattern.match(creditsRaw))
                        {
                            orderedFields.push(orderPattern.matched(1));
                            creditsRaw = orderPattern.matchedRight();
                        }
                        
                        for(fieldName in orderedFields)
                        {
                            if(Reflect.hasField(creditsObj, fieldName))
                            {
                                var value:Dynamic = Reflect.field(creditsObj, fieldName);
                                var names:Array<String> = Std.isOfType(value, Array) ? cast value : [cast value];
                                credits.push({role: fieldName, names: names});
                            }
                        }
                    }
                }
                else
                {
                    if(jsonData.creditsA != null)
                        credits.push({role: "Artist", names: jsonData.creditsA});
                    if(jsonData.creditsCO != null)
                        credits.push({role: "Composer", names: jsonData.creditsCO});
                    if(jsonData.creditsCH != null)
                        credits.push({role: "Charter", names: jsonData.creditsCH});
                    if(jsonData.creditsCOD != null)
                        credits.push({role: "Coder", names: jsonData.creditsCOD});
                }
                
                return {
                    credits: credits,
                    showAllCredits: jsonData.showAllCredits != null ? jsonData.showAllCredits : false
                };
            }
            catch (e)
            {
                trace('Error parsing metadata: $e');
                return getDefault();
            }
        }

        return getDefault();
    }

    static function getDefault():SongMeta
    {
        return {
            credits: [
                {role: "Artist", names: [""]},
                {role: "Composer", names: [""]},
                {role: "Charter", names: [""]},
                {role: "Coder", names: [""]}
            ],
            showAllCredits: false
        };
    }
    static function findMatchingBrace(str:String, startPos:Int):Int
    {
        var count:Int = 1;
        var pos:Int = startPos + 1;
        
        while(pos < str.length && count > 0)
        {
            if(str.charAt(pos) == '{') count++;
            else if(str.charAt(pos) == '}') count--;
            pos++;
        }
        
        return pos - 1;
    }
}