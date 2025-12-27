package funkin.jit;

import funkin.jit.script.LuaScript;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.sound.FlxSound;

interface ILuaState {
    public var stateLua:LuaScript;
    public var _cancel:Bool;

    public var sprites:Map<String, FlxSprite>;
    public var texts:Map<String, FlxText>;
    public var tweens:Map<String, FlxTween>;
    public var timers:Map<String, FlxTimer>;
    public var sounds:Map<String, FlxSound>;
    public var variables:Map<String, Dynamic>;

    public function getLuaObject(tag:String, text:Bool=true):FlxSprite;
}