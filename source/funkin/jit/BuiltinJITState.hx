package funkin.jit;

import llua.Lua;
import llua.State;
import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import Type.ValueType;
import funkin.jit.script.LuaScript;
import animateatlas.AtlasFrameMaker;
import flixel.FlxSubState;

import funkin.component.*;

class BuiltinJITState extends MusicBeatState implements ILuaState {

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
        stateLua = new LuaScript("scripts/states/"+ path, this, function (lua:LuaScript) { registerCallback(lua); });
    }

    override function destroy() {
        super.destroy();
        clearCache();
    }

    // public function clearVar() { variables.clear(); }
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
        // clearVar();
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
        // if(variables.exists(tag)) return variables.get(tag);
        return null;
    }

    public static function registerCallback(object:LuaScript) {
        var lua:State = object.lua;
        var target:ILuaState = cast (object.target, ILuaState);

        // Reflection callbacks
        Lua_helper.add_callback(lua, "getProperty",
		function (variable:String) {
			var result:Dynamic = null;
			var array:Array<String> = variable.split('.');
			if (array.length > 1) 
				result = getVarInArray(target, getPropertyLoop(target, array), array[array.length - 1]);
			else
				result = getVarInArray(target, target, variable);
			return result;
		});
		Lua_helper.add_callback(lua, "setProperty",
		function (variable:String, value:Dynamic) {
			var array:Array<String> = variable.split('.');
			if (array.length > 1)
			{
				setVarInArray(target, getPropertyLoop(target, array), array[array.length - 1], value);
				return true;
			}
			setVarInArray(target, target, variable, value);
			return true;
		});
		Lua_helper.add_callback(lua, "getPropertyFromClass", 
		function(classVar:String, variable:String) {
			@:privateAccess
			var array:Array<String> = variable.split('.');
			if (array.length > 1) {
				var target:Dynamic = getVarInArray(target, Type.resolveClass(classVar), array[0]);
				for (i in 1...array.length - 1) {
					target = getVarInArray(target, target, array[i]);
				}
				return getVarInArray(target, target, array[array.length - 1]);
			}
			return getVarInArray(target, Type.resolveClass(classVar), variable);
		});
		Lua_helper.add_callback(lua, "setPropertyFromClass", 
		function(classVar:String, variable:String, value:Dynamic) {
			@:privateAccess
			var array:Array<String> = variable.split('.');
			if (array.length > 1) {
				var target:Dynamic = getVarInArray(target, Type.resolveClass(classVar), array[0]);
				for (i in 1...array.length - 1) {
					target = getVarInArray(target, target, array[i]);
				}
				setVarInArray(target, target, array[array.length - 1], value);
				return true;
			}
			setVarInArray(target, Type.resolveClass(classVar), variable, value);
			return true;
		});
		Lua_helper.add_callback(lua, "getPropertyFromGroup",
		function (obj:String, index:Int, variable:Dynamic) {
			var array:Array<String> = obj.split('.');
			var realObject:Dynamic = Reflect.getProperty(target, obj);
			if (array.length > 1)
				realObject = getPropertyLoop(target, array, true, false);

			if (Std.isOfType(realObject, FlxTypedGroup)) {
				var result:Dynamic = getGroupStuff(realObject.members[index], variable);
				return result;
			}

			var group:Dynamic = realObject[index];
			if (group != null) {
				var result:Dynamic = null;

				if (Type.typeof(variable) == ValueType.TInt) result = group[variable];
				else result = getGroupStuff(group, variable);
				return result;
			}
			object.error("getPropertyFromGroup: Object #" + index + " from group: " + obj + " doesn't exist!");
			return null;
		});
 		Lua_helper.add_callback(lua, "removeFromGroup",
		function (obj:String, index:Int, dontDestroy:Bool = false) {
			if (Std.isOfType(Reflect.getProperty(target, obj), FlxTypedGroup)) {
				var target = Reflect.getProperty(target, obj).members[index];
				if (!dontDestroy) target.kill();
				Reflect.getProperty(target, obj).remove(target, true);
				if (!dontDestroy) target.destroy();
				return;
			}
			Reflect.getProperty(target, obj).remove(Reflect.getProperty(target, obj)[index]);
		});
		Lua_helper.add_callback(lua, "setPropertyFromGroup",
		function (obj:String, index:Int, variable:Dynamic, value:Dynamic) {
			var array:Array<String> = obj.split('.');
			var realObject:Dynamic = Reflect.getProperty(target, obj);
			if (array.length > 1) realObject = getPropertyLoop(target, array, true, false);

			if (Std.isOfType(realObject, FlxTypedGroup)) {
				setGroupStuff(realObject.members[index], variable, value);
				return;
			}

			var group:Dynamic = realObject[index];
			if (group != null) {
				if (Type.typeof(variable) == ValueType.TInt) {
					group[variable] = value;
					return;
				}
				setGroupStuff(group, variable, value);
			}
		});

		// State JIT
		Lua_helper.add_callback(lua, "openSubState", function(name:String){
			if (!Std.isOfType(target, FlxSubState)) {
				var parent:FlxState = (cast (target, FlxState));
				parent.openSubState(CoolUtil.getSubStateByString(name));
			}
		});
		Lua_helper.add_callback(lua, "closeSubState", function(){
			if (Std.isOfType(target, BuiltinJITState)) (cast (target, BuiltinJITState)).closeSubState();
			else (cast (target, BuiltinJITSubState)).close();
		});
		Lua_helper.add_callback(lua, "switchState", function (state:String){MusicBeatState.switchState(CoolUtil.getStateByString(state));});
		Lua_helper.add_callback(lua, "instantSwitchState", function (state:String){FlxG.switchState(CoolUtil.getStateByString(state));});

		/*
		 	flixel stuff
		*/
		Lua_helper.add_callback(lua, "getObjectOrder", function(obj:String)
		{
			var array:Array<String> = obj.split('.');
			var tar:FlxBasic = getObjectDirectly(target, array[0]);
			if (array.length > 1) tar = getVarInArray(target, getPropertyLoop(target, array), array[array.length - 1]);

			if (tar != null) return convertedParent(target).members.indexOf(tar);

			object.error("getObjectOrder: Object " + obj + " doesn't exist!");
			return -1;
		});
		Lua_helper.add_callback(lua, "setObjectOrder", function(obj:String, position:Int)
		{
			var array:Array<String> = obj.split('.');
			var tar:FlxBasic = getObjectDirectly(target, array[0]);
			if (array.length > 1) tar = getVarInArray(target, getPropertyLoop(target, array), array[array.length - 1]);

			if (tar != null) {
				convertedParent(target).remove(tar, true);
				convertedParent(target).insert(position, tar);
				return;
			}
			object.error("setObjectOrder: Object " + obj + " doesn't exist!");
		});

		// FlxSprite
		Lua_helper.add_callback(lua, "makeLuaSprite",
		function (tag:String, image:String, x:Float, y:Float) {
			tag = StringTools.replace(tag, ".", "");
			resetSpriteTag(target, tag);

			var sprite:FlxSprite = new FlxSprite(x, y);
			if (image != null && image.length > 0) sprite.loadGraphic(Paths.image(image));

			sprite.antialiasing = ClientPrefs.globalAntialiasing;

			target.sprites.set(tag, sprite);
			sprite.active = true;
		});
		Lua_helper.add_callback(lua, "makeGraphic",
		function (obj:String, width:Int, height:Int, r:Int = 255, g:Int = 255, b:Int = 255, a:Int = 255) {
			var spr:FlxSprite = target.sprites.get(obj);
			var color:FlxColor = new FlxColor();
			if (spr != null) spr.makeGraphic(width, height, color.setRGB(r, g, b, a));
		});
		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite",
		function (tag:String, image:String, x:Float, y:Float, ?spriteType:String = "sparrow") {
			tag = StringTools.replace(tag, ".", "");
			resetSpriteTag(target, tag);

			var sprite:FlxSprite = new FlxSprite(x, y);
			if (image != null && image.length > 0) sprite.loadGraphic(Paths.image(image));

			// loadFrames

			switch (StringTools.trim(spriteType.toLowerCase()))
			{
				case "texture" | "textureatlas" | "tex":
					sprite.frames = AtlasFrameMaker.construct(image);

				case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
					sprite.frames = AtlasFrameMaker.construct(image, null, true);

				case "packer" | "packeratlas" | "pac":
					sprite.frames = Paths.getPackerAtlas(image);

				default:
					sprite.frames = Paths.getSparrowAtlas(image);
			}

			sprite.antialiasing = ClientPrefs.globalAntialiasing;

			target.sprites.set(tag, sprite);
		});
		Lua_helper.add_callback(lua, "addLuaSprite",
		function (tag:String, front:Bool = false) {
			if (target.sprites.exists(tag)) {
				convertedParent(target).add(target.sprites.get(tag));
			}
		});
		Lua_helper.add_callback(lua, "addAnimationByPrefix",
		function (obj:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) {
			var sprite:FlxSprite = target.sprites.get(obj);
			if (sprite != null) {
				sprite.animation.addByPrefix(name, prefix, framerate, loop);
				if (sprite.animation.curAnim == null) sprite.animation.play(name, true);
			}
		});
		Lua_helper.add_callback(lua, "addAnimationByIndices",
		function (obj:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			return addAnimByIndices(target, obj, name, prefix, indices, framerate, false);
		});
		Lua_helper.add_callback(lua, "addAnimationByIndicesLoop",
		function (obj:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			return addAnimByIndices(target, obj, name, prefix, indices, framerate, true);
		});
		Lua_helper.add_callback(lua, "addAnimation",
		function (obj:String, name:String, frames:Array<Int>, framerate:Int = 24, loop:Bool = true) {
			var sprite:FlxSprite = target.sprites.get(obj);
			if (sprite != null)
			{
				sprite.animation.add(name, frames, framerate, loop);
				if (sprite.animation.curAnim == null)
				{
					sprite.animation.play(name, true);
				}
			}
		});
		Lua_helper.add_callback(lua, "playAnim",
		function (obj:String, name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0) {
			if (target.sprites.exists(obj)) {
				var sprite:FlxSprite = target.sprites.get(obj);
				if (sprite.animation.getByName(name) != null) {
					sprite.animation.play(name, forced, reverse, startFrame);
				}
			}
		});
		Lua_helper.add_callback(lua, "loadGraphic", function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = getObjectDirectly(target, split[0]);
			var animated = gridX != 0 || gridY != 0;

			if(split.length > 1) spr = getVarInArray(target, getPropertyLoop(target, split), split[split.length-1]);
			if(spr != null && image != null && image.length > 0) spr.loadGraphic(Paths.image(image), animated, gridX, gridY);
		});
		Lua_helper.add_callback(lua, "loadFrames", function(variable:String, image:String, spriteType:String = 'auto') {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = getObjectDirectly(target, split[0]);
			if(split.length > 1) spr = getVarInArray(target, getPropertyLoop(target, split), split[split.length-1]);

			if(spr != null && image != null && image.length > 0) {
				switch (StringTools.trim(spriteType.toLowerCase())) {
					case "texture" | "textureatlas" | "tex":
						spr.frames = AtlasFrameMaker.construct(image);

					case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
						spr.frames = AtlasFrameMaker.construct(image, null, true);

					case "packer" | "packeratlas" | "pac":
						spr.frames = Paths.getPackerAtlas(image);

					default:
						spr.frames = Paths.getSparrowAtlas(image);
				}
			}
		});
		Lua_helper.add_callback(lua, "setBlendMode",
		function(obj:String, blend:String = '') {
			var real = target.getLuaObject(obj);
			if (real != null)
			{
				real.blend = CoolUtil.blendModeFromString(blend);
				return true;
			}

			var killMe:Array<String> = obj.split('.');
			var spr:FlxSprite = getObjectDirectly(target, killMe[0]);
			if (killMe.length > 1) spr = getVarInArray(target, getPropertyLoop(target, killMe), killMe[killMe.length - 1]);

			if (spr != null) {
				spr.blend = CoolUtil.blendModeFromString(blend);
				return true;
			}
			object.error("setBlendMode: Object " + obj + " doesn't exist!");
			return false;
		});
		// FlxTween
		Lua_helper.add_callback(lua, "doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			doTween(object, tag, vars, {x: value}, duration, ease);});
		Lua_helper.add_callback(lua, "doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			doTween(object, tag, vars, {y: value}, duration, ease);});
		Lua_helper.add_callback(lua, "doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			doTween(object, tag, vars, {angle: value}, duration, ease);});
		Lua_helper.add_callback(lua, "doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			doTween(object, tag, vars, {alpha: value}, duration, ease);});
		Lua_helper.add_callback(lua, "doTweenZoom", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			doTween(object, tag, vars, {zoom: value}, duration, ease);});
		Lua_helper.add_callback(lua, "doTweenColor", function(tag:String, vars:String, r:Int = 255, g:Int = 255, b:Int = 255, a:Int = 255, duration:Float, ease:String) {
			if(tag != null) cancelTween(target, tag);
			var variables:Array<String> = vars.split('.');
			var penisExam:Dynamic = getObjectDirectly(target, variables[0]);
			if(variables.length > 1) penisExam = getVarInArray(target, getPropertyLoop(target, variables), variables[variables.length-1]);
			if (penisExam != null) {
				var color:FlxColor = new FlxColor();

				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				target.tweens.set(tag, FlxTween.color(penisExam, duration, curColor, color.setRGB(r, g, b, a), {
					ease: CoolUtil.getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						target.tweens.remove(tag);
						object.call("onTweenCompleted", [tag]);
					}}));
			} else object.error('doTweenColor: Couldnt find object: ' + vars);
		});
		// FlxTimer
		Lua_helper.add_callback(lua, "runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			cancelTimer(target, tag);
			target.timers.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if(tmr.finished) target.timers.remove(tag);
					object.call('onTimerCompleted', [tag, tmr.loops, tmr.loopsLeft]);
			}, loops));
			return tag;
		});
		Lua_helper.add_callback(lua, "cancelTimer", function(tag:String) cancelTimer(target, tag));
// FlxText
		Lua_helper.add_callback(lua, "makeLuaText",
		function(tag:String, text:String, width:Int, x:Float, y:Float) {
			tag = StringTools.replace(tag, '.', '');

			if (target.texts.exists(tag)) {
				var textRemove:FlxText = target.texts.get(tag);
				textRemove.kill();
				
				if (textRemove.active) convertedParent(target).remove(textRemove, true);
				
				textRemove.destroy();
				target.texts.remove(tag);
			}

			var text:FlxText = new FlxText(x, y, text, width);
			text.active = false;
			target.texts.set(tag, text);
		});
		Lua_helper.add_callback(lua,  "setTextFont",
		function(tag:String, newFont:String) {
			var obj:FlxText = target.texts.get(tag);
			if (obj != null) {
				obj.font = Paths.font(newFont);
				return true;
			}

			object.error("setTextFont: Object " + tag + " doesn't exist!");
			return false;
		});
		Lua_helper.add_callback(lua,  "setTextColor", function(tag:String, r:Int = 255, g:Int = 255, b:Int = 255, a:Int = 255) {
			var obj:FlxText = target.texts.get(tag);
			if (obj != null) {
				var color:FlxColor = new FlxColor();
				obj.color = color.setRGB(r, g, b, a);
				return true;
			}
			object.error("setTextColor: Object " + tag + " doesn't exist!");
			return false;
		});
		Lua_helper.add_callback(lua,  "addLuaText",
		function(tag:String) {
			if (target.texts.exists(tag)) {
				var shit:FlxText = target.texts.get(tag);
				if (!shit.active) {
					convertedParent(target).add(shit);
					shit.active = true;
					// trace('added a thing: ' + tag);
				}
			}
		});
		Lua_helper.add_callback(lua,  "removeLuaText",
		function(tag:String, destroy:Bool = true) {
			if (!target.texts.exists(tag)) return;

			var textRemove:FlxText = target.texts.get(tag);
			if (destroy) textRemove.kill();

			if (textRemove.active) {
				convertedParent(target).remove(textRemove, true);
				textRemove.active = false;
			}

			if (destroy) {
				textRemove.destroy();
				target.texts.remove(tag);
			}
		});
		// FlxG.keys
		Lua_helper.add_callback(lua, "keyboardJustPressed",
		function(name:String) {
			return Reflect.getProperty(FlxG.keys.justPressed, name);
		});
		Lua_helper.add_callback(lua, "keyboardPressed",
		function(name:String) {
			return Reflect.getProperty(FlxG.keys.pressed, name);
		});
		Lua_helper.add_callback(lua, "keyboardReleased",
		function(name:String) {
			return Reflect.getProperty(FlxG.keys.justReleased, name);
		});
		// FlxG.sound
		Lua_helper.add_callback(lua, "playMusic",
		function(sound:String, volume:Float = 1, loop:Bool = false) {
			FlxG.sound.playMusic(Paths.music(sound), volume, loop);
		});
		Lua_helper.add_callback(lua, "playSound",
		function(sound:String, volume:Float = 1, ?tag:String = null) {
			if (tag != null && tag.length > 0) {
				tag = StringTools.replace(tag, '.', '');
				if (target.sounds.exists(tag)) target.sounds.get(tag).stop();
				target.sounds.set(tag, FlxG.sound.play(Paths.sound(sound), volume, false, function() {
					target.sounds.remove(tag);
					object.call('onSoundFinished', [tag]);
				}));
				return;
			}
			FlxG.sound.play(Paths.sound(sound), volume);
		});
		Lua_helper.add_callback(lua, "stopSound",
		function(tag:String) {
			if (tag != null && tag.length > 1 && target.sounds.exists(tag)) {
				target.sounds.get(tag).stop();
				target.sounds.remove(tag);
			}
		});
		Lua_helper.add_callback(lua, "pauseSound",
		function(tag:String) {
			if (tag != null && tag.length > 1 && target.sounds.exists(tag)) target.sounds.get(tag).pause();
		});
		Lua_helper.add_callback(lua, "resumeSound",
		function(tag:String) {
			if (tag != null && tag.length > 1 && target.sounds.exists(tag)) target.sounds.get(tag).play();
		});
		Lua_helper.add_callback(lua, "soundFadeIn",
		function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			if (tag == null || tag.length < 1) FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			else if (target.sounds.exists(tag)) target.sounds.get(tag).fadeIn(duration, fromValue, toValue);
		});
		Lua_helper.add_callback(lua, "soundFadeOut",
		function(tag:String, duration:Float, toValue:Float = 0) {
			if (tag == null || tag.length < 1) FlxG.sound.music.fadeOut(duration, toValue);
			else if (target.sounds.exists(tag)) target.sounds.get(tag).fadeOut(duration, toValue);
		});
		Lua_helper.add_callback(lua, "soundFadeCancel",
		function(tag:String) {
			if (tag == null || tag.length < 1) {
				if (FlxG.sound.music.fadeTween != null)
					FlxG.sound.music.fadeTween.cancel();
			}
			else if (target.sounds.exists(tag)) {
				var theSound:FlxSound = target.sounds.get(tag);
				if (theSound.fadeTween != null) {
					theSound.fadeTween.cancel();
					target.sounds.remove(tag);
				}
			}
		});
		Lua_helper.add_callback(lua, "getSoundVolume",
		function(tag:String) {
			if (tag == null || tag.length < 1) if (FlxG.sound.music != null) return FlxG.sound.music.volume;
			else if (target.sounds.exists(tag)) return target.sounds.get(tag).volume;
			return 0;
		});
		Lua_helper.add_callback(lua, "setSoundVolume",
		function(tag:String, value:Float) {
			if (tag == null || tag.length < 1) if (FlxG.sound.music != null) FlxG.sound.music.volume = value;
			else if (target.sounds.exists(tag)) target.sounds.get(tag).volume = value;
		});
		Lua_helper.add_callback(lua, "getSoundTime",
		function(tag:String) {
			if (tag != null && tag.length > 0 && target.sounds.exists(tag)) return target.sounds.get(tag).time;
			return 0;
		});
		Lua_helper.add_callback(lua, "setSoundTime",
		function(tag:String, value:Float) {
			if (tag != null && tag.length > 0 && target.sounds.exists(tag)) {
				var theSound:FlxSound = target.sounds.get(tag);
				if (theSound != null) {
					var wasResumed:Bool = theSound.playing;
					theSound.pause();
					theSound.time = value;
					if (wasResumed)
						theSound.play();
				}
			}
		});
    }

    public static function resetSpriteTag(parent:ILuaState, tag:String) {
		if (!parent.sprites.exists(tag)) return;

		var sprite:FlxSprite = parent.sprites.get(tag);
		sprite.kill();
		if (sprite.active) cast (parent, FlxState).remove(sprite, true);

		sprite.destroy();
		parent.sprites.remove(tag);
	}

	public static function addAnimByIndices(parent:ILuaState, obj:String, name:String, prefix:String, indices:String, framerate:Int = 24, loop:Bool = false) {
		var strIndices:Array<String> = StringTools.trim(indices).split(',');
		var indices:Array<Int> = [];
		for (i in 0...strIndices.length) {
			indices.push(Std.parseInt(strIndices[i]));
		}

		if (parent.sprites.exists(obj)) {
			var sprite:FlxSprite = parent.sprites.get(obj);
			sprite.animation.addByIndices(name, prefix, indices, '', framerate, loop);
			if (sprite.animation.curAnim == null) sprite.animation.play(name, true);
			return true;
		}

		return false;
	}

	public static function cancelTimer(parent:ILuaState, tag:String) {
		if (parent.timers.exists(tag)) {
			var timer:FlxTimer = parent.timers.get(tag);
			timer.cancel();
			timer.destroy();
			parent.timers.remove(tag);
		}
	}

	public static function cancelTween(parent:ILuaState, tag:String) {
		if (parent.tweens.exists(tag)) {
			parent.tweens.get(tag).cancel();
			parent.tweens.get(tag).destroy();
			parent.tweens.remove(tag);
		}
	}

	public static function doTween(lua:LuaScript, tag:String, vars:String, values:Dynamic, duration:Float, ease:String) {
		var parent:ILuaState = cast (lua.target, ILuaState);
        cancelTween(parent, tag);
		var variables:Array<String> = vars.split('.');
		var tweenTarget:Dynamic = getObjectDirectly(parent, variables[0]);
		if (variables.length > 1) tweenTarget = getVarInArray(parent, getPropertyLoop(parent, variables), variables[variables.length - 1]);

		if (tweenTarget != null) {
			parent.tweens.set(tag, FlxTween.tween(tweenTarget, values, duration, {
				ease: CoolUtil.getFlxEaseByString(ease),
				onComplete: function(twn:FlxTween) {
					// TODO PlayState
//					if (!Std.isOfType(parent, PlayState)) {
						lua.call("onTweenCompleted", [tag]);
						parent.tweens.remove(tag);
//					}
				}}));
		} else lua.error('doTween: Couldnt find object: ' + vars);
	}

	public static function convertedParent(parent:ILuaState):FlxState {
		return Std.isOfType(parent, BuiltinJITState) ? (cast (parent, BuiltinJITState)) : (cast (parent, FlxState));
	}

    /*
     *  Reflection
    */
    public static function getPropertyLoop(parent:ILuaState, array:Array<String>, ?checkForTextsToo:Bool = true, ?getProperty:Bool = true):Dynamic {
		var result:Dynamic = getObjectDirectly(parent, array[0], checkForTextsToo);
		var end = array.length;
		if (getProperty) end = array.length - 1;

		for (i in 1...end) {
			result = getVarInArray(parent, result, array[i]);
		}
		return result;
	}

	public static function getObjectDirectly(parent:ILuaState, objectName:String, ?checkForTextsToo:Bool = true):Dynamic {
		var result:Dynamic = parent.getLuaObject(objectName, checkForTextsToo);
		if (result == null) return getVarInArray(parent, parent, objectName);
		return result;
	}

	public static function setVarInArray(parent:ILuaState, instance:Dynamic, variable:String, value:Dynamic):Any {
		var array:Array<String> = variable.split('[');
		if (array.length > 1) {
			var result:Dynamic = null;
			if (parent.variables.exists(array[0])) {
				var retVal:Dynamic = parent.variables.get(array[0]);
				if (retVal != null) result = retVal;
			} else result = Reflect.getProperty(instance, array[0]);

			for (i in 1...array.length) {
				var leNum:Dynamic = array[i].substr(0, array[i].length - 1);
				if (i >= array.length - 1) result[leNum] = value; // Last array
				else result = result[leNum]; // Anything else
			}
			return result;
		}
		/*if(Std.isOfType(instance, Map))
				instance.set(variable,value);
			else */

		if (parent.variables.exists(variable)) {
			parent.variables.set(variable, value);
			return true;
		}

		Reflect.setProperty(instance, variable, value);
		return true;
	}

	public static function getGroupStuff(group:Dynamic, variable:String)
	{
		var array:Array<String> = variable.split('.');
		if (array.length > 1) {
			var property:Dynamic = Reflect.getProperty(group, array[0]);
			for (i in 1...array.length - 1) {
				property = Reflect.getProperty(property, array[i]);
			}
			switch (Type.typeof(property)) {
				case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
					return property.get(array[array.length - 1]);
				default:
					return Reflect.getProperty(property, array[array.length - 1]);
			};
		}
		switch (Type.typeof(group)) {
			case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
				return group.get(variable);
			default:
				return Reflect.getProperty(group, variable);
		};
	}

	public static function setGroupStuff(group:Dynamic, variable:String, value:Dynamic)
	{
		var array:Array<String> = variable.split('.');
		if (array.length > 1) {
			var property:Dynamic = Reflect.getProperty(group, array[0]);
			for (i in 1...array.length - 1) {
				property = Reflect.getProperty(property, array[i]);
			}
			Reflect.setProperty(property, array[array.length - 1], value);
			return;
		}
		Reflect.setProperty(group, variable, value);
	}

	public static function getVarInArray(parent:ILuaState, instance:Dynamic, variable:String):Any {
		var array:Array<String> = variable.split('[');
		if (array.length > 1) {
			var result:Dynamic = null;
			if (parent.variables.exists(array[0])) {
				var retVal:Dynamic = parent.variables.get(array[0]);
				if (retVal != null)
					result = retVal;
			} else result = Reflect.getProperty(instance, array[0]);

			for (i in 1...array.length) {
				var leNum:Dynamic = array[i].substr(0, array[i].length - 1);
				result = result[leNum];
			}
			return result;
		}

		if (parent.variables.exists(variable)) {
			var retVal:Dynamic = parent.variables.get(variable);
			if (retVal != null) return retVal;
		}

		return Reflect.getProperty(instance, variable);
	}
}