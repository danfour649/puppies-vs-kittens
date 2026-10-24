package PuppiesVsKittens;

import javafx.animation.*;
import javafx.application.Application;
import javafx.fxml.FXMLLoader;
import javafx.scene.Group;
import javafx.scene.Scene;
import javafx.scene.canvas.Canvas;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.control.Label;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.StackPane;
import javafx.scene.paint.Color;
import javafx.stage.Stage;
import javafx.stage.StageStyle;
import javafx.util.Duration;

import java.io.FileNotFoundException;

/**
 *
 */
public class Main extends Application {
    public static final KvPModel model = new KvPModel();

    // Need to catch possible file not found exceptions when instantiating view.
    public static KvPView view = null;
    static {
        try { view = new KvPView();
            } catch (FileNotFoundException e) {
                e.printStackTrace();
            }
    }
    public static final KvPViewController view_CONTROLLER = new KvPViewController();

    @Override
    public void start(Stage primaryStage) throws Exception{
            Group root = new Group();
            view.setPrefSize(500,500);
            Scene scene = new Scene(root,500,500);
            primaryStage.setScene(scene);

        try {
            // Setup the splash screen
            Stage splashStage = new Stage(StageStyle.UNDECORATED);
            StackPane splashPane = FXMLLoader.load(getClass().getResource(("SplashScreen.fxml")));
            Scene splashScene = new Scene(splashPane, 500, 500);
            splashStage.setScene(splashScene);
            FadeTransition fade = new FadeTransition(Duration.seconds(5), splashPane);
            fade.setFromValue(1);
            fade.setToValue(0.3);
            fade.setCycleCount(1);
            fade.play();
            fade.setOnFinished((e) -> {
                splashStage.close();
                primaryStage.show();
            });

            // Setup the game screen
            Canvas canvas = new Canvas(500,500);
            root.getChildren().add(canvas);
            root.getChildren().add(view);

            GraphicsContext gc = canvas.getGraphicsContext2D();
            long startTime = System.nanoTime();
            model.initializeGame();

            new AnimationTimer() {
                int clockTime = 0;
                public void handle(long currentTime) {
                    gc.setFill(Color.PAPAYAWHIP);
                    gc.fillRect(0,0,500,500);
                    gc.setStroke(Color.DARKCYAN);
                    gc.strokeText(("Time: " + Main.model.getClockTime()), 420, 50);

                    if (((currentTime-startTime)/1000000000) > clockTime+1) {
                        if (!model.finished()) {
                            clockTime++;
                            model.setClockTime(model.getClockTime() + 1);
                            Main.model.unFightKitten();
                            Main.model.unFightMice(clockTime);
                            Main.model.checkFightPuppies();
                        }
                    }
                    model.movePuppies();
                    model.moveMice();
                    view.layoutChildren();
                }
            }.start();

            splashStage.show();
        } catch(Exception e) {
            System.out.println("Problem running KvP game: " + e.getMessage());
            e.getStackTrace();
        }
    }

    public static void main(String[] args) {
        launch(args);
    }
}
