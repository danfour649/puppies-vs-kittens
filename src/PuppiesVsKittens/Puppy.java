package PuppiesVsKittens;

import javafx.beans.property.SimpleBooleanProperty;
import javafx.beans.property.SimpleDoubleProperty;
import javafx.scene.layout.StackPane;

public class Puppy extends StackPane {
    protected SimpleDoubleProperty x, y;
    protected SimpleBooleanProperty fighting;

    public Puppy(Double x, Double y) {
     this.x = new SimpleDoubleProperty(x);
     this.y = new SimpleDoubleProperty(y);
     this.fighting = new SimpleBooleanProperty(false);
    }
}
