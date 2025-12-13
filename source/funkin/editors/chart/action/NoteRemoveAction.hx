package funkin.editors.chart.action;

import funkin.editors.chart.ChartEditorState;
import funkin.editors.chart.element.GuiNote;
import flixel.FlxG;

class NoteRemoveAction extends ChartEditorState.EditorAction {
    private var _note:GuiNote;

    public var strumTime:Float = 0;
    public var noteData:Int = 0;
    public var susLength:Float = 0;
    public var noteType:String = "";

    public function new(note:GuiNote) {
        super();

        strumTime = note.strumTime;
        noteData = note.noteData;
        susLength = note.susLength;
        noteType = note.noteType;

        _note = note;

        redo();
    }

    override function redo() {
        ChartEditorState.INSTANCE.renderNotes.remove(_note.susTail);
        ChartEditorState.INSTANCE.renderNotes.remove(_note);
        _note = null;
    }

    override function undo() {
        _note = new GuiNote(strumTime, noteData, susLength);
        _note.noteType = noteType;
        ChartEditorState.INSTANCE.renderNotes.add(_note);
    }
}