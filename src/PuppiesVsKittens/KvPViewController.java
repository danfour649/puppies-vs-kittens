package PuppiesVsKittens;


import javafx.event.EventHandler;
import javafx.scene.Node;
import javafx.scene.control.Label;
import javafx.scene.input.KeyCode;
import javafx.scene.input.KeyEvent;
import javafx.scene.input.MouseEvent;
import javafx.scene.paint.Color;
import javafx.scene.shape.Rectangle;

public class KvPViewController {
    public enum State {READY, CREATING_VERTEX, SELECTED_VERTEX, MOVING_VERTEX, DRAWING_EDGE;}
    private State state;
    private Mouse currentMouse;
    private Integer vertexNumber = 0;
    private double origX = 0, origY = 0;
    private double xStart = 0, yStart = 0;
    private int startVertex = -1;

    public KvPViewController() {
        state = State.READY;
        Main.view.addEventHandler(MouseEvent.ANY, new EventHandler<MouseEvent>() {
            @Override
            public void handle(MouseEvent event) {
                if (event.isPrimaryButtonDown() && (event.getTarget().getClass().equals(Rectangle.class) || event.getTarget().getClass().equals(Label.class))) {
                    System.out.println("Mouse pressed at: " + event.getX() + " / " + event.getY());
                }
            }
        });

        Main.view.addEventFilter(KeyEvent.ANY, new EventHandler<KeyEvent>() {
            @Override
            public void handle(KeyEvent event) {
                if (event.getCode().isArrowKey()) {
                    Main.model.moveKitten(event.getCode());
                    event.consume();
                }

                if (event.getCode().equals(KeyCode.SPACE)) {
                    Main.model.fightKitten();
                    event.consume();
                }
            }
        });
    }
}