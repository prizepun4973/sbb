package funkin.jit.script;

import sys.FileSystem;
import funkin.jit.BuiltinJITState;
import hscript.Parser;
import hscript.Interp;
import hscript.Expr;

import flixel.FlxState;
import funkin.game.component.Character;

class HScript extends Script {

    function setup() {
        addClass('FlxG', 'flixel');
		interp.variables.set('FlxSprite', flixel.FlxSprite);
		interp.variables.set('FlxCamera', flixel.FlxCamera);
		interp.variables.set('FlxTimer', flixel.util.FlxTimer);
		interp.variables.set('FlxTween', flixel.tweens.FlxTween);
		interp.variables.set('FlxEase', flixel.tweens.FlxEase);
		interp.variables.set('PlayState', PlayState);
		interp.variables.set('game', PlayState.instance);
		interp.variables.set('Paths', Paths);
		interp.variables.set('Conductor', Conductor);
		interp.variables.set('ClientPrefs', ClientPrefs);
		interp.variables.set('Character', funkin.game.component.Character);
		interp.variables.set('Alphabet', funkin.component.Alphabet);
		interp.variables.set('CustomSubstate', funkin.game.jit.FunkinLua.CustomSubstate);
        #if (!flash && sys)interp.variables.set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);#end
		interp.variables.set('ShaderFilter', openfl.filters.ShaderFilter);
		interp.variables.set('StringTools', StringTools);

        /**
		 * lua jit
		 */
		interp.variables.set('setVar', function(name:String, value:Dynamic) { convertedParent().variables.set(name, value); });
		interp.variables.set('getVar', function(name:String){ 
			if (convertedParent().variables.exists(name)) return convertedParent().variables.get(name);
			return null;
		});
		interp.variables.set('removeVar', function(name:String) {
			if (convertedParent().variables.exists(name)) {
				convertedParent().variables.remove(name);
				return true;
			}
			return false;
		});
    }

	public static var parser:Parser = new Parser();
	public var interp:Interp;
    public var code:String = "";

    public var path:String;

	public function new(path:String, target:FlxState) {
        super(path, target);
		interp = new Interp();
        interp.scriptObject = target;
        this.target = target;
        this.path = path;

        // https://github.com/CodenameCrew/CodenameEngine
        interp.variables.set("trace", Reflect.makeVarArgs((args) -> {
			var v:String = Std.string(args.shift());
			for (a in args) v += ", " + Std.string(a);
			this.trace(v);
		}));

        setup();

        if (FileSystem.exists(Paths.hscript(path))) execute(Paths.getTextFromFile(Paths.hscript(path)));
	}

    function addClass(libName:String, libPackage:String) {
        interp.variables.set(libName, Type.resolveClass(libPackage + "." + libName));
    }

	public function execute(codeToRun:String):Dynamic {
		@:privateAccess
		HScript.parser.line = 1;
		HScript.parser.allowTypes = true;

        code = codeToRun;
		return interp.execute(HScript.parser.parseString(codeToRun));
	}

    function convertedParent():Dynamic {
        return Std.isOfType(target, ILuaState) ? (cast (target, ILuaState)) : (cast (target, PlayState));
    }

	public function trace(v:Dynamic) {
        if (path == "") trace(Std.string(v));
		else trace(path + '.hx: ' + Std.string(v));
	}
}