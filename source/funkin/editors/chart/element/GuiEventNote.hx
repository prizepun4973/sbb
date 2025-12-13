package funkin.editors.chart.element;

import funkin.editors.chart.ChartEditorState;
import funkin.editors.chart.ChartEditorState.GuiElement;
import funkin.game.component.Note.EventNote;

class GuiEventNote extends GuiElement {
    public var events:Array<EventNote> = new Array();

    public function new(strumTime:Float, events:Array<EventNote>) {
        super(0, 0);

        this.strumTime = strumTime;
        this.events = events;

        loadGraphic(Paths.image("eventArrow"));
        setGraphicSize(ChartEditorState.GRID_SIZE, ChartEditorState.GRID_SIZE);
        centerOffsets();
        centerOrigin();

        updatePos();
    }

    override function updatePos() {
        x = ChartEditorState.INSTANCE.nextGridBG.x - ChartEditorState.GRID_SIZE - 3;
        y = (ChartEditorState.Y_OFFSET - ChartEditorState.GRID_SIZE - 3) - ((Conductor.songPosition - ChartEditorState.calcY(strumTime)) * ChartEditorState.GRID_SIZE / Conductor.crochet * 4);
        alpha = strumTime < Conductor.songPosition ? 0.6 : 1;
    }
}