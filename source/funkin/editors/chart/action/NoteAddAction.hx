package funkin.editors.chart.action;

import funkin.editors.chart.ChartEditorState;
import funkin.editors.chart.action.NoteAddAction;
import funkin.editors.chart.element.GuiNote;
import flixel.FlxG;

class NoteAddAction extends ChartEditorState.EditorAction {
    public var _note:GuiNote;

    public var strumTime:Float;
    public var noteData:Int;
    public var wasSelected:Bool = false;

    public function new(strumTime, noteData) {
        super();

        this.strumTime = strumTime;
        this.noteData = noteData;

        ChartEditorState.INSTANCE.selectIndicator.forEachAlive(function (indicator:SelectIndicator) {
            if (indicator.target == _note) wasSelected = true;
        });

        redo();
    }

    override function redo() {
        _note = new GuiNote(strumTime, noteData, 0, this);
        if (wasSelected) ChartEditorState.INSTANCE.selectIndicator.add(new SelectIndicator(_note));
    }

    override function undo() {

        ChartEditorState.INSTANCE.selectIndicator.forEachAlive(function (indicator:SelectIndicator) {
            if (indicator.target == _note) {
                wasSelected = true;
                ChartEditorState.INSTANCE.selectIndicator.remove(indicator);
            }
        });

        ChartEditorState.INSTANCE.renderNotes.remove(_note.susTail);
        ChartEditorState.INSTANCE.renderNotes.remove(_note);
    }
}