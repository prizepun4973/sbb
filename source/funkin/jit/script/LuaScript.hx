package funkin.jit.script;

import sys.FileSystem;
import flixel.FlxState;
import llua.Convert;
import llua.Lua;
import llua.LuaL;
import llua.State;
import StringTools;

import flixel.util.FlxColor;

class LuaScript extends Script {
    public static var Function_Stop:Dynamic = "##PSYCHLUA_FUNCTIONSTOP";
	public static var Function_Continue:Dynamic = "##PSYCHLUA_FUNCTIONCONTINUE";
	public static var Function_StopLua:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA";

    public var lua:State = LuaL.newstate();
    public var scriptName:String = '';

	public static var hscript:HScript = null;
    
    public function new(script:String, target:FlxState, registerCallback:LuaScript -> Void = null) {
        super(script, target);
        this.target = target;

        LuaL.openlibs(lua);
		Lua.init_callbacks(lua);

        if (!FileSystem.exists(Paths.lua(script))) {
			lua = null;
			return;
		}

        var result:Dynamic = LuaL.dofile(lua, Paths.lua(script));
		var resultStr:String = Lua.tostring(lua, result);

		if (resultStr != null && result != 0) {
			trace("Failed to load " + script + ".lua: " + resultStr);
			lua = null;
			return;
		}

        scriptName = script;
        trace('Loaded lua: ' + script + '.lua');

		initHaxeModule();

		Lua_helper.add_callback(lua, "trace",function (text:String) {trace(scriptName + ": " + text);});
        // StringTools
        Lua_helper.add_callback(lua, "stringStartsWith", function(str:String, start:String) {return StringTools.startsWith(str, start);});
		Lua_helper.add_callback(lua, "stringEndsWith",function(str:String, end:String) {return StringTools.endsWith(str, end);});
		Lua_helper.add_callback(lua, "stringSplit",function(str:String, split:String) {return str.split(split);});
		Lua_helper.add_callback(lua, "stringTrim",function(str:String) {return StringTools.trim(str);});

		// hscript
		Lua_helper.add_callback(lua, "runHaxeCode", function(codeToRun:String) {
			var retVal:Dynamic = null;

			initHaxeModule();
			try {
				retVal = hscript.execute(codeToRun);
			}
			catch (e:Dynamic) {
				trace(scriptName + ":" + lastCalledFunction + " - " + e, false, false, FlxColor.RED);
			}

			if (retVal != null && !isOfTypes(retVal, [Bool, Int, Float, String, Array])) retVal = null;
			return retVal;
		});
		Lua_helper.add_callback(lua, "addHaxeLibrary", function(libName:String, ?libPackage:String = ''){
			initHaxeModule();
			try {
				var str:String = '';
				if (libPackage.length > 0) str = libPackage + '.';

				hscript.interp.variables.set(libName, Type.resolveClass(str + libName));
			}
			catch (e:Dynamic) trace(scriptName + ":" + lastCalledFunction + " - " + e, false, false, FlxColor.RED);
		});

		if (registerCallback != null) registerCallback(this);
    }

    override function set(variable:String, data:Dynamic) {
		if (lua == null) return;

		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
	}

	var lastCalledFunction:String = '';
    override function call(event:String, args:Array<Dynamic>):Dynamic {
		if (lua == null) return Function_Continue;

		lastCalledFunction = event;

		Lua.getglobal(lua, event);

		for (arg in args) {
			Convert.toLua(lua, arg);
		}

		var result:Null<Int> = Lua.pcall(lua, args.length, 1, 0);

		// Makes it ignore warnings

		var allowed;

		switch (Lua.type(lua, result)) {
			case Lua.LUA_TNIL | Lua.LUA_TBOOLEAN | Lua.LUA_TNUMBER | Lua.LUA_TSTRING | Lua.LUA_TTABLE:
				allowed = true;
			default:
				allowed = false;
		}

		if (result != null && allowed) {
			/*
			var resultStr:String = Lua.tostring(lua, result);
			var error:String = Lua.tostring(lua, -1);
			Lua.pop(lua, 1);
			*/
			if (Lua.type(lua, -1) == Lua.LUA_TSTRING) {
				var error:String = Lua.tostring(lua, -1);
				Lua.pop(lua, 1);
				if (error == 'attempt to call a nil value') return Function_Continue; // Makes it ignore warnings and not break stuff if you didn't put the functions on your lua file
			} return Convert.fromLua(lua, result);
		}

		return Function_Continue;
	}

    override function stop() {
		if (lua == null) return;

		Lua.close(lua);
		lua = null;
	}

    public function error(text:String) {
		trace(scriptName + ": " + text);
	}

	public function initHaxeModule() {
		if (hscript == null) {
			trace('initializing haxe interp for: $scriptName');
			hscript = new HScript('', target); // TO DO: Fix issue with 2 scripts not being able to use the same variable names
		}
	}

	public static function isOfTypes(value:Any, types:Array<Dynamic>) {
		for (type in types)
		{
			if (Std.isOfType(value, type))
				return true;
		}
		return false;
	}
}