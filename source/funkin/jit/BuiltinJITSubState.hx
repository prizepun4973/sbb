package funkin.jit;

import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import funkin.jit.script.LuaScript;

import funkin.component.*;

class BuiltinJITSubState extends MusicBeatSubstate implements ILuaState {

    public var stateLua:LuaScript;
    public var _cancel:Bool;

    public var sprites:Map<String, FlxSprite> = new Map();
    public var texts:Map<String, FlxText> = new Map();
    public var tweens:Map<String, FlxTween> = new Map();
    public var timers:Map<String, FlxTimer> = new Map();
    public var sounds:Map<String, FlxSound> = new Map();
    public var variables:Map<String, Dynamic> = new Map();

    public function new(path:String) {
        super();
        _cancel = false;
        stateLua = new LuaScript("scripts/states/substate/"+ path, this, function (lua:LuaScript) { BuiltinJITState.registerCallback(lua); });
    }

    override function destroy() {
        super.destroy();
        clearCache();
    }

    public function clearVar() { variables.clear(); }
    function clearSprites():Void { sprites.clear(); }
    function clearTweens():Void { tweens.clear(); }
    function clearTimers():Void { timers.clear(); }
    function clearSounds():Void { sounds.clear(); }
    function clearTexts():Void { texts.clear(); }
    function clearCache():Void {
        clearSprites();
        clearTweens();
        clearTimers();
        clearSounds();
        clearTexts();
        clearVar();
    }

    function call(name:String, args:Array<Dynamic>):Bool {
        if (stateLua != null) stateLua.call(name, args);

        var result:Bool = false;
        if (_cancel == true) {
            result = true;
            _cancel = false;
        }
        return result;
    }

    public function getLuaObject(tag:String, text:Bool=true):FlxSprite {
        if(sprites.exists(tag)) return sprites.get(tag);
        if(text && texts.exists(tag)) return texts.get(tag);
        if(variables.exists(tag)) return variables.get(tag);
        return null;
    }
}