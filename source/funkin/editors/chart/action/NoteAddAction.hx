package funkin.editors.chart.action;

import funkin.editors.chart.ChartEditorState;
import funkin.editors.chart.element.GuiNote;
import flixel.FlxG;

class NoteAddAction extends ChartEditorState.EditorAction {
    private var _note:GuiNote;

    public var strumTime:Float;
    public var noteData:Int;
    
    public function new(strumTime, noteData) {
        super();

        this.strumTime = strumTime;
        this.noteData = noteData;

        redo();
    }

    override function redo() {
        _note = new GuiNote(strumTime, noteData, 0);
    }

    override function undo() {
        ChartEditorState.INSTANCE.renderNotes.remove(_note.susTail);
        ChartEditorState.INSTANCE.renderNotes.remove(_note);
    }
}