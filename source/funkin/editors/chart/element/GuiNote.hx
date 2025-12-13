package funkin.editors.chart.element;

import funkin.editors.chart.ChartEditorState;
import funkin.editors.chart.ChartEditorState.GuiElement;
import flixel.FlxSprite;
import flixel.text.FlxText;

class GuiNote extends GuiElement{
    public var noteData:Int = 0;
    public var susLength:Float = 0;
    public var noteType:String = "";
    
    public var susTail:FlxSprite;
    public var typeTxt:FlxText;

    public function new(strumTime:Float, noteData:Int, susLength) {
        super(0, 0);

        var parent = ChartEditorState.INSTANCE.renderNotes;
        this.strumTime = strumTime;
        this.noteData = noteData;
        this.susLength = susLength;

        loadGraphic(Paths.image("NOTE_assets"));
        frames = Paths.getSparrowAtlas("NOTE_assets");
        setGraphicSize(ChartEditorState.GRID_SIZE, ChartEditorState.GRID_SIZE);
        centerOffsets();
        centerOrigin();
        
		susTail = new FlxSprite(0, 0).makeGraphic(8, 1);

        switch (noteData) {
            case 0 | 4 :
                animation.addByPrefix("note", "purple0");
                susTail.color = 0xdda0dd;
            case 1 | 5 :
                animation.addByPrefix("note", "blue0");
                susTail.color = 0x00ffff;
            case 2 | 6 :
                animation.addByPrefix("note", "green0");
                susTail.color = 0x5CE65C;
            case 3 | 7 :
                animation.addByPrefix("note", "red0");
                susTail.color = 0xED2939;
        }

        animation.play("note");

        parent.add(susTail);
        parent.add(this);

        updatePos();
    }

    override function updatePos() {        
        var crochet:Float = (60 / Conductor.getBPMFromSeconds(Conductor.songPosition).bpm) * 1000;

        x =  ChartEditorState.INSTANCE.nextGridBG.x - ChartEditorState.GRID_SIZE * 1.5 + (noteData + 1) * ChartEditorState.GRID_SIZE + 2;
        y = (ChartEditorState.Y_OFFSET - ChartEditorState.GRID_SIZE * 1.5) - ((Conductor.songPosition - ChartEditorState.calcY(strumTime)) / crochet * 4 * ChartEditorState.GRID_SIZE);
        alpha = strumTime < Conductor.songPosition ? 0.6 : 1;

        crochet = (60 / Conductor.getBPMFromSeconds(strumTime).bpm) * 1000;

        susTail.x = x + (ChartEditorState.GRID_SIZE * 2) - 6;
        susTail.y = y + ChartEditorState.GRID_SIZE * 2.25 + (ChartEditorState.GRID_SIZE * (susLength / crochet * 2));
        susTail.visible = susLength > 0;
        susTail.alpha = alpha;
        susTail.setGraphicSize(susTail.width, ChartEditorState.GRID_SIZE * (susLength / crochet * 4 + 0.5));
    }
}