package PuppiesVsKittens;

import javafx.beans.property.SimpleBooleanProperty;
import javafx.beans.property.SimpleDoubleProperty;
import javafx.beans.property.SimpleIntegerProperty;
import javafx.scene.layout.StackPane;
import javafx.scene.paint.Color;
import javafx.scene.shape.Circle;

public class Mouse extends StackPane {
    protected SimpleDoubleProperty x, y;
    protected SimpleBooleanProperty fighting, dead;
    protected SimpleIntegerProperty timeToLiveAfterHurt;

    public Mouse(Double x, Double y) {
     this.x = new SimpleDoubleProperty(x);
     this.y = new SimpleDoubleProperty(y);
     this.fighting = new SimpleBooleanProperty(false);
     this.dead = new SimpleBooleanProperty(false);
     this.timeToLiveAfterHurt = new SimpleIntegerProperty(3);
    }
}
