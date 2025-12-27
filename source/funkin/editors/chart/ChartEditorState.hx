package funkin.editors.chart;

import flixel.text.FlxText;
import funkin.jit.BuiltinJITState;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.addons.display.FlxGridOverlay;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxStringUtil;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.FlxG;
import flixel.group.FlxGroup.FlxTypedGroup;
import Song.SwagSong;
import funkin.component.MusicBeatState;
import funkin.game.component.Note.EventNote;
import funkin.game.data.StageData;
import funkin.game.data.Section.SwagSection;

import openfl.display.BlendMode;

import openfl.utils.Assets as OpenFlAssets;
import flash.media.Sound;

#if sys
import sys.FileSystem;
#end

import Conductor.BPMChangeEvent;

import funkin.editors.chart.element.*;
import funkin.editors.chart.action.*;

using StringTools;

class ChartEditorState extends BuiltinJITState {
    public static var GRID_SIZE:Int = 40;
    public static var Y_OFFSET:Int = 360;
    public static var INSTANCE:ChartEditorState;

    public static var lastPos:Float = 0;
    public static var curSec:Int = 0;
    public static var lastUpdateTime:Float;
    public static var nextUpdateTime:Float;
    
    public var paused:Bool = true;
    public static var undos:Array<EditorAction> = new Array();
    public static var redos:Array<EditorAction> = new Array();

    public var beatSnap:Int = 32;

    // data
    public var _song:SwagSong;
    private var sectionBPM:Array<Float> = new Array();

    // audio
    private var vocals:FlxSound = null;

    // graphics
    public var renderNotes:FlxTypedGroup<FlxSprite> = new FlxTypedGroup();
    public var gridBG:FlxSprite;
    public var nextGridBG:FlxSprite;
    private var gridGroup:FlxTypedGroup<FlxSprite> = new FlxTypedGroup();
    private var eventSplitLine:FlxSprite;
    private var sideSplitLine:FlxSprite;
    private var conductorLine:FlxSprite;
    private var sectionStartLine:FlxSprite;
    private var sectionStopLine:FlxSprite;

    private var textPanel:FlxText;
    public var crosshair:Crosshair;
    public var selectIndicator:FlxTypedGroup<SelectIndicator> = new FlxTypedGroup();
    
    public static function reset() {
        lastPos = 0;
        lastUpdateTime = 0;
        nextUpdateTime = 0;
        curSec = 0;
        undos = new Array<EditorAction>();
        redos = new Array<EditorAction>();
    }
    
    public static function getMousePos() {
        var strumTime:Float = Conductor.songPosition + (FlxG.mouse.y - Y_OFFSET) / (GRID_SIZE / Conductor.crochet * 4);
        var map:BPMChangeEvent;
        var crochet:Float;
        if (Conductor.songPosition <= strumTime) {
            map = Conductor.getBPMFromSeconds(strumTime);
            crochet = (60 / map.bpm) * 1000;
        }
        else {
            map = Conductor.getBPMFromSeconds(Conductor.songPosition);
            crochet = (60 / Conductor.getBPMFromSeconds(strumTime).bpm) * 1000;
        }
        
        return map.songTime + ((strumTime - map.songTime) * crochet / Conductor.crochet);
    }

    public static function calcY(strumTime:Float = 0) {
        var map:BPMChangeEvent;
        var crochet:Float;
        if (Conductor.songPosition <= strumTime) {
            map = Conductor.getBPMFromSeconds(strumTime);
            crochet = (60 / map.bpm) * 1000;
        }
        else {
            map = Conductor.getBPMFromSeconds(Conductor.songPosition);
            crochet = (60 / Conductor.getBPMFromSeconds(strumTime).bpm) * 1000;
        }
        
        return map.songTime + ((strumTime - map.songTime) / crochet * Conductor.crochet);
    }

    public function removeElement(element:GuiElement) {
        var wasSelected = false;
        selectIndicator.forEachAlive(function (indicator:SelectIndicator) {
            if (indicator.target == element) {
                wasSelected = true;
                ChartEditorState.INSTANCE.selectIndicator.remove(indicator);
            }
        });

        renderNotes.remove(element);
    }

    public function addElement(element:GuiElement, wasSelected:Bool = false) {
        renderNotes.add(element);
        if (wasSelected) selectIndicator.add(new SelectIndicator(element));
    }

    public function addAction(action:EditorAction) {
        undos.push(action);
        if (redos.length > 0) redos = new Array<EditorAction>();
    }

    function pause() {
        if (paused) { // resume
            FlxG.sound.music.time = Conductor.songPosition;
            if (vocals != null) {
                vocals.time = FlxG.sound.music.time;
                vocals.resume();
            }
            FlxG.sound.music.resume();
        }
        else { // pause
            FlxG.sound.music.pause();
            if (vocals != null) vocals.pause();
        }
        paused = !paused;
    }
    
    public function updateCurSec() {
        var songPos:Float = Conductor.songPosition;

        if (curSec < 0 || Conductor.songPosition < 0) {
            curSec = 0;
            Conductor.changeBPM(sectionBPM[0]);
            lastUpdateTime = 0;
            nextUpdateTime = _song.notes[curSec].sectionBeats * Conductor.crochet;

            gridBG.setGraphicSize(gridBG.width, GRID_SIZE * _song.notes[curSec].sectionBeats * 4);
            conductorLine.color = sectionBPM[curSec] == sectionBPM[curSec + 1] ? FlxColor.WHITE : FlxColor.YELLOW;

            songPos = 0;
            Conductor.songPosition = 0;
            if (!paused) pause();
        }

        if (songPos > nextUpdateTime) {
            curSec++;

            if (curSec >= _song.notes.length) {
                curSec--;

                var sec:SwagSection = {
                    sectionBeats: _song.notes[curSec].sectionBeats,
                    bpm: sectionBPM[curSec],
                    changeBPM: false,
                    mustHitSection: _song.notes[curSec].mustHitSection,
                    gfSection: _song.notes[curSec].gfSection,
                    sectionNotes: [],
                    typeOfSection: 0,
                    altAnim: _song.notes[curSec].altAnim
                };
                _song.notes.push(sec);

                sectionBPM.push(sectionBPM[curSec]);

                curSec++;
            }

            Conductor.changeBPM(sectionBPM[curSec]);
            
            lastUpdateTime = nextUpdateTime;
            nextUpdateTime += _song.notes[curSec].sectionBeats * Conductor.crochet;

            gridBG.setGraphicSize(gridBG.width, GRID_SIZE * _song.notes[curSec].sectionBeats * 4);
        }
        if (songPos < lastUpdateTime && songPos > 0) {
            curSec--;
            Conductor.changeBPM(sectionBPM[curSec]);

            nextUpdateTime = lastUpdateTime;
            lastUpdateTime -= _song.notes[curSec].sectionBeats * Conductor.crochet;

            gridBG.setGraphicSize(gridBG.width, GRID_SIZE * _song.notes[curSec].sectionBeats * 4);
        }
    }

    function saveChanges() {
        _song.events = new Array();

        for (section in _song.notes) {
            section.sectionNotes = new Array<Dynamic>();
        }

        renderNotes.forEachAlive(function (i:FlxSprite) {
            if (Std.isOfType(i, GuiNote)) {
                var note:GuiNote = (cast (i, GuiNote));

                var targetSection:Int = 0;
                var endTime:Float = 0;
                while (endTime < note.strumTime) {
                    endTime += _song.notes[targetSection].sectionBeats * (60 / sectionBPM[curSec]) * 1000;
                    targetSection++;
                }

                if (targetSection >= _song.notes.length) targetSection--;

                var noteArray:Array<Dynamic> = new Array();
                noteArray.push(note.strumTime);
                noteArray.push(Std.int(_song.notes[targetSection].mustHitSection ? (note.noteData < 4 ? note.noteData + 4 : note.noteData - 4) : note.noteData));
                noteArray.push(note.susLength);
                if (note.noteType != '') noteArray.push(note.noteType);

                _song.notes[targetSection].sectionNotes.push(noteArray);
            }

            if (Std.isOfType(i, GuiEventNote)) {
                var event:GuiEventNote = (cast (i, GuiEventNote));

                var eventArray:Array<Dynamic> = new Array();
                eventArray.push(event.strumTime);
                eventArray.push(event.events);

                _song.events.push(eventArray);
            }
        });

        PlayState.SONG = _song;
    }
    

    public function new() {
        super("ChartEditorState");
        INSTANCE = this;
    }
    
    override function destroy() {
        super.destroy();
        lastPos = Conductor.songPosition;
    }

    override function create() {
        super.create();

        FlxG.mouse.visible = true;
        Conductor.songPosition = lastPos;

        /*
            load
        */
        if (PlayState.SONG != null) _song = PlayState.SONG;
		else {
			CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
			_song = {
				song: 'Test',
				notes: [],
				events: [],
				bpm: 150.0,
				needsVoices: true,
				arrowSkin: '',
				splashSkin: 'noteSplashes',
				player1: 'bf',
				player2: 'dad',
				gfVersion: 'gf',
				speed: 1,
				stage: 'stage',
				validScore: false
			};
			PlayState.SONG = _song;
		}
        Conductor.mapBPMChanges(_song);
		Conductor.changeBPM(_song.bpm);

        var lastBPM:Float = _song.bpm;
        for (section in _song.notes) {
            if (!Std.isOfType(section.sectionBeats, Float) || section.sectionBeats < 1) section.sectionBeats = 4;

            if (section.changeBPM) lastBPM = section.bpm;
            sectionBPM.push(lastBPM);
        }

        /*
            audio
        */
        FlxG.sound.playMusic(Paths.inst(_song.song));
        FlxG.sound.music.pause();

        vocals = new FlxSound();
		if (FileSystem.exists('assets/songs/${Paths.formatToSongPath(_song.song)}/Voices.ogg') || FileSystem.exists('${Paths.modFolders("songs/")}${Paths.formatToSongPath(_song.song)}/Voices.ogg')){
			var file:Dynamic = Paths.voices(_song.song);
			if (Std.isOfType(file, Sound) || OpenFlAssets.exists(file)) {
				vocals.loadEmbedded(file);
				FlxG.sound.list.add(vocals);
			}
		}
        vocals.play();
        vocals.pause();

        FlxG.sound.music.onComplete = function () {
			if(vocals != null) {
                vocals.play();
                vocals.pause();
			}
            curSec = -1;
		};

        /*
            graphics
        */
        add(gridGroup);

        nextGridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 9, GRID_SIZE * 50);
        nextGridBG.alpha = 0.8;
        nextGridBG.screenCenter(X);
        nextGridBG.x -= GRID_SIZE / 2;
        nextGridBG.y = Y_OFFSET;
        gridGroup.add(nextGridBG);

        gridBG = new FlxSprite().makeGraphic(GRID_SIZE * 9, GRID_SIZE * 16, FlxColor.WHITE);
        gridBG.screenCenter(X);
        gridBG.alpha = 0.3;
        gridBG.x -= GRID_SIZE / 2;
        gridGroup.add(gridBG);

        sideSplitLine = new FlxSprite(nextGridBG.x + GRID_SIZE * 5, 0).makeGraphic(2, Std.int(nextGridBG.height), FlxColor.BLACK);
        gridGroup.add(sideSplitLine);
        eventSplitLine = new FlxSprite(nextGridBG.x + GRID_SIZE, 0).makeGraphic(2, Std.int(nextGridBG.height), FlxColor.BLACK);
        gridGroup.add(eventSplitLine);

        add(selectIndicator);
        add(renderNotes);

        for (section in _song.notes) {
            for (note in section.sectionNotes) {
                var guiNote:GuiNote = new GuiNote(note[0], Std.int(section.mustHitSection ? (note[1] < 4 ? note[1] + 4 : note[1] - 4) : note[1]), note[2]);
                if (note.length > 3) if (Std.isOfType(note[3], String)) guiNote.noteType = note[3];
            }
        }

        for (event in _song.events) {
            var guiEventNote:GuiEventNote = new GuiEventNote(event[0], event[1]);
            renderNotes.add(guiEventNote);
        }

        if (curSec == 0) {
            lastUpdateTime = 0;
            nextUpdateTime = _song.notes[curSec].sectionBeats * Conductor.crochet;
        }

        var wip:FlxText = new FlxText(2, FlxG.height - 28, 400, "chart editor is wip, plz press debugkey1", 12);
        wip.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, FlxTextAlign.LEFT);
        add(wip);

        sectionStartLine = new FlxSprite(0, Y_OFFSET).makeGraphic(GRID_SIZE * 13, 4, FlxColor.WHITE);
        sectionStartLine.screenCenter(X);
        sectionStartLine.x -= GRID_SIZE / 2;
        add(sectionStartLine);

        sectionStopLine = new FlxSprite(0, Y_OFFSET).makeGraphic(GRID_SIZE * 13, 4, FlxColor.WHITE);
        sectionStopLine.screenCenter(X);
        sectionStopLine.x -= GRID_SIZE / 2;
        add(sectionStopLine);

        conductorLine = new FlxSprite(0, Y_OFFSET).makeGraphic(GRID_SIZE * 13, 4, 0xffBD99FF);
        conductorLine.screenCenter(X);
        conductorLine.x -= GRID_SIZE / 2;
        add(conductorLine);

        crosshair = new Crosshair();
        add(crosshair);

        add(new FlxSprite(0, 0).makeGraphic(FlxG.width, 20, 0xffBD99FF));
        add(new FlxSprite(0, 20).makeGraphic(FlxG.width, 80, 0x64BD99FF));
        
        textPanel = new FlxText(5, 45, 400, "hi", 12);
        textPanel.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(textPanel);

        updateCurSec();
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
        call("onUpdate", [elapsed]);
        var songPos:Float = Conductor.songPosition;

        /*
            System
        */
        if (Conductor.songPosition < 0) Conductor.songPosition = 0;
        if (Conductor.songPosition >= FlxG.sound.music.length) Conductor.songPosition = FlxG.sound.music.length;
        if (!paused) Conductor.songPosition = FlxG.sound.music.time;

        if (renderNotes.members.length <= 0) updateCurSec();

        /*
            handle graphic
        */
        nextGridBG.y = Y_OFFSET - (songPos - lastUpdateTime + Conductor.crochet * 2) * GRID_SIZE / Conductor.crochet * 4 - GRID_SIZE * 5;
        gridBG.y = Y_OFFSET - (songPos - lastUpdateTime) * GRID_SIZE / Conductor.crochet * 4;
        sectionStartLine.y = gridBG.y;
        sectionStopLine.y = Y_OFFSET - (songPos - nextUpdateTime) * GRID_SIZE / Conductor.crochet * 4;

        textPanel.text = 
            FlxStringUtil.formatTime(Conductor.songPosition / 1000, true) + " / " + FlxStringUtil.formatTime(FlxG.sound.music.length / 1000, true) + " (" + Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2)) + ")" +
		    "\nBeat: " + curBeat + " | Step: " + curStep + 
            "\nSection: " + curSec + " (Beats: " + _song.notes[curSec].sectionBeats + ", BPM: " + sectionBPM[curSec] + ")";

        /*
            handle inputs
        */
        actionListener();

        if (FlxG.keys.justPressed.ENTER) {
            if (!paused) pause();
            saveChanges();
            FlxG.mouse.visible = false;
            StageData.loadDirectory(_song);
            LoadingState.loadAndSwitchState(new PlayState());
        }
        if (((FlxG.mouse.wheel > 0 && Conductor.songPosition > 0) || (FlxG.mouse.wheel < 0 && Conductor.songPosition < FlxG.sound.music.length)) && paused)
            Conductor.songPosition -= Conductor.crochet * FlxG.mouse.wheel;
        if (FlxG.keys.justPressed.SPACE) pause();

        // selection
        if (FlxG.mouse.justPressed && crosshair.target != null) {
            if (FlxG.keys.pressed.CONTROL) {
                var isSelected:Bool = false;
                selectIndicator.forEachAlive(function (indicator:SelectIndicator) {
                    if (indicator.target == crosshair.target) isSelected = true;
                });

                if (!isSelected) selectIndicator.add(new SelectIndicator(crosshair.target));
                else selectIndicator.forEachAlive(function (indicator:SelectIndicator) {
                    if (indicator.target == crosshair.target) selectIndicator.remove(indicator);
                });
            }
        }

        if (FlxG.keys.pressed.DELETE) {
            var toDelete:Array<GuiElement> = new Array();

            selectIndicator.forEachAlive(function (indicator:SelectIndicator) {
                toDelete.push(indicator.target); 
            });

            if (toDelete.length > 0) addAction(new ElementRemoveAction(toDelete));
        }

        // undo / redo
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Z && undos.length > 0) {
            undos[undos.length - 1].undo();
            redos.push(undos[undos.length - 1]);
            undos.pop();
            // trace(undos);
            // trace(redos);
        }
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.Y && redos.length > 0) {
            redos[redos.length - 1].redo();
            undos.push(redos[redos.length - 1]);
            redos.remove(redos[redos.length - 1]);
            trace(undos);
            trace(redos);
        }

        // wip
        if (FlxG.keys.anyJustPressed(ClientPrefs.copyKey(ClientPrefs.keyBinds.get('debug_1')))) {
            funkin.component.MusicBeatState.switchState(new funkin.editors.ChartingState());
        }
    }
    

    function actionListener() {
        if (crosshair.visible) {
            if (FlxG.mouse.pressed && !FlxG.keys.pressed.CONTROL && !FlxG.keys.pressed.SHIFT && crosshair.target == null && paused) {
                if (FlxG.mouse.x > gridBG.x + GRID_SIZE) {
                    addAction(new NoteAddAction(
                        crosshair.chained? crosshair.chainedMousePos : getMousePos(), 
                        Math.floor((FlxG.mouse.x - gridBG.x - GRID_SIZE) / GRID_SIZE))
                    );
                }
                else addAction(new EventAddAction(crosshair.chained? crosshair.chainedMousePos : getMousePos()));
            }

            if (FlxG.mouse.pressedRight && !FlxG.keys.pressed.CONTROL && crosshair.target != null && !FlxG.keys.pressed.SHIFT && paused) {
                addAction(new ElementRemoveAction([crosshair.target]));
            }
        }
    }
}

class SelectIndicator extends FlxSprite {
    public var target:GuiElement;

    public function new(target:GuiElement) {
        super(0, 0);

        this.target = target;

        makeGraphic(ChartEditorState.GRID_SIZE, ChartEditorState.GRID_SIZE, 0xff00FFFF);

        updatePos();
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
        updatePos();
    }

    function updatePos() {
        x = target.x + ChartEditorState.GRID_SIZE * 1.5 - 2;
        y = target.y + ChartEditorState.GRID_SIZE * 1.5;
    }
}

class Crosshair extends FlxSprite {
    public var target:GuiElement;
    public var chained:Bool = true;
    public var chainedMousePos:Float;

    public function new() {
        super(0, 0);
        makeGraphic(ChartEditorState.GRID_SIZE, ChartEditorState.GRID_SIZE, 0xffBD99FF);
        alpha = 0.5;
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
        var editor:ChartEditorState = ChartEditorState.INSTANCE;

        var mouseStrumTime:Float = ChartEditorState.getMousePos();
        var GRID_SIZE = ChartEditorState.GRID_SIZE;

        chainedMousePos = Conductor.getBPMFromSeconds(mouseStrumTime).songTime + Math.floor((mouseStrumTime - Conductor.getBPMFromSeconds(mouseStrumTime).songTime) / Conductor.getCrochetAtTime(mouseStrumTime) / 4 * editor.beatSnap) * Conductor.getCrochetAtTime(mouseStrumTime) * 4 / editor.beatSnap;
        x = editor.gridBG.x + Math.floor((FlxG.mouse.x - editor.gridBG.x) / GRID_SIZE) * GRID_SIZE;
        y = chained? ChartEditorState.Y_OFFSET - (Conductor.songPosition - ChartEditorState.calcY(chainedMousePos)) * GRID_SIZE / Conductor.crochet * 4
         : FlxG.mouse.y - height / 2;
        visible = FlxG.mouse.x >= editor.gridBG.x && FlxG.mouse.x < editor.gridBG.x + editor.gridBG.width
            && mouseStrumTime >= 0 && mouseStrumTime <= FlxG.sound.music.length && FlxG.mouse.y > 100;

        var anyHovered = false;
        editor.renderNotes.forEachAlive(function (sprite:FlxSprite) {
            if (Std.isOfType(sprite, GuiElement)) {
                var hitboxScale = 16 / editor.beatSnap * ChartEditorState.GRID_SIZE;
                var element:GuiElement = cast (sprite, GuiElement);
                var x1:Float = element.x + GRID_SIZE * 1.5 - 2;
                var y1:Float = element.y + GRID_SIZE * 1.5;
                var x2:Float = x1 + GRID_SIZE;
                var y2:Float = y1 + hitboxScale;

                if (FlxG.mouse.x >= x1 && FlxG.mouse.x <= x2 && FlxG.mouse.y >= y1 && FlxG.mouse.y <= y2 && !anyHovered) {
                    target = element;
                    anyHovered = true;
                }
                else if (!anyHovered) target = null;
            }
            else if (!anyHovered) target = null;
        });
    }
}

class GuiElement extends FlxSprite {
    public var strumTime:Float = 0;
    public var relatedAction:EditorAction;
    public var relatedRemove:EditorAction;

    public function new(X:Float = 0, Y:Float = 0) {
        super(X, Y);
    }

    override function update(elapsed:Float) {
        ChartEditorState.INSTANCE.updateCurSec();
        updatePos();
        super.update(elapsed);
    }

    function updatePos() {}
}

abstract class EditorAction {
    public var editor:ChartEditorState = ChartEditorState.INSTANCE;
    public function new() {}
    public function redo() {}
    public function undo() {}
}