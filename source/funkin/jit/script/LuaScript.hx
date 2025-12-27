package funkin.jit.script;

import sys.FileSystem;
import flixel.FlxState;
import llua.Convert;
import llua.Lua;
import llua.LuaL;
import llua.State;
import StringTools;

class LuaScript extends Script {
    public static var Function_Stop:Dynamic = "##PSYCHLUA_FUNCTIONSTOP";
	public static var Function_Continue:Dynamic = "##PSYCHLUA_FUNCTIONCONTINUE";
	public static var Function_StopLua:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA";

    public var lua:State = LuaL.newstate();

    public var scriptName:String = '';
    
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

		Lua_helper.add_callback(lua, "trace",function (text:String) {trace(scriptName + ": " + text);});
        // StringTools
        Lua_helper.add_callback(lua, "stringStartsWith", function(str:String, start:String) {return StringTools.startsWith(str, start);});
		Lua_helper.add_callback(lua, "stringEndsWith",function(str:String, end:String) {return StringTools.endsWith(str, end);});
		Lua_helper.add_callback(lua, "stringSplit",function(str:String, split:String) {return str.split(split);});
		Lua_helper.add_callback(lua, "stringTrim",function(str:String) {return StringTools.trim(str);});

		if (registerCallback != null) registerCallback(this);
    }

    override function set(variable:String, data:Dynamic) {
		if (lua == null) return;

		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
	}

    override function call(event:String, args:Array<Dynamic>):Dynamic {
		if (lua == null) return Function_Continue;

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
}