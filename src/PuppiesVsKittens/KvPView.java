package PuppiesVsKittens;

import javafx.collections.ListChangeListener;
import javafx.event.EventHandler;
import javafx.geometry.Pos;
import javafx.scene.canvas.Canvas;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.control.*;
import javafx.scene.image.ImageView;
import javafx.scene.input.MouseEvent;
import javafx.scene.layout.Pane;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;
import javafx.scene.paint.Color;
import javafx.scene.shape.Rectangle;
import javafx.scene.text.Font;

import java.io.FileNotFoundException;
import java.util.Optional;


public class KvPView extends Pane {
    private Canvas canvas;
    public static final Color green = Color.LIGHTGREEN;
    public static final Color red = Color.SALMON;
    public static final Color blue = Color.LIGHTBLUE;
    public static String mode = new String("medium");
    public static ImageView mouseImageView = null;
    public static ImageView kittenImageView = null;
    public static ImageView puppyImageView = null;
    public static ImageView altMouseImageView = null;
    public static ImageView altKittenImageView = null;
    public static ImageView altPuppyImageView = null;
    public static ImageView kittenDeadImageView = null;
    public static ImageView splashScreen = null;

    public KvPView() throws FileNotFoundException {
        mouseImageView = new ImageView(getClass().getResource("m.png").toExternalForm());
        kittenImageView = new ImageView(getClass().getResource("k.png").toExternalForm());
        puppyImageView = new ImageView(getClass().getResource("p.png").toExternalForm());
        altMouseImageView = new ImageView(getClass().getResource("m2.png").toExternalForm());
        altKittenImageView = new ImageView(getClass().getResource("k2.png").toExternalForm());
        altPuppyImageView = new ImageView(getClass().getResource("p2.png").toExternalForm());
        kittenDeadImageView = new ImageView(getClass().getResource("k3.png").toExternalForm());
        splashScreen = new ImageView(getClass().getResource("KvPlogo.png").toExternalForm());
        canvas = new Canvas();
        canvas.setLayoutX(0);
        canvas.setWidth(0);
        this.getChildren().add(canvas);

        Main.model.mouseListProperty().addListener(new ListChangeListener<Mouse>() {
            @Override
            public void onChanged(Change<? extends Mouse> s) {
                requestLayout();
            }
        });

        Main.model.showSplash().addListener((observable, oldValue, newValue) -> {
            System.out.println("splash off");
            this.getChildren().clear();
        });

        // create the toolbar & buttons
        ToolBar toolBar = new ToolBar();
        toolBar.setMinWidth(500);
        ToggleGroup group = new ToggleGroup();

        ToggleButton greenButton = new ToggleButton("EASY");
        greenButton.setStyle("-fx-base: lightgreen;");
        greenButton.setSelected(true);
        greenButton.setTooltip(new Tooltip("EASY MODE"));
        greenButton.setToggleGroup(group);
        greenButton.addEventHandler(MouseEvent.MOUSE_CLICKED,
                new EventHandler<MouseEvent>() {
                    @Override public void handle(MouseEvent e) {
                        Main.model.setSelectedMode("easy");
                    }
                });
        toolBar.getItems().add(greenButton);

        // MEDIUM MODE BUTTON HERE
        ToggleButton blueButton = new ToggleButton("MEDIUM");
        blueButton.setStyle("-fx-base: lightblue;");
        blueButton.setSelected(false);
        blueButton.setTooltip(new Tooltip("MEDIUM MODE (DEFAULT)"));
        blueButton.setToggleGroup(group);
        blueButton.addEventHandler(MouseEvent.MOUSE_CLICKED,
                new EventHandler<MouseEvent>() {
                    @Override public void handle(MouseEvent e) {
                        System.out.println("Change to Medium mode");
                        Main.model.setSelectedMode("medium");
                    }
                });
        toolBar.getItems().add(blueButton);

        // Hard mode BUTTON HERE
        ToggleButton redButton = new ToggleButton("HARD");
        redButton.setStyle("-fx-base: salmon;");
        redButton.setSelected(false);
        redButton.setTooltip(new Tooltip("HARD MODE"));
        redButton.setToggleGroup(group);
        redButton.addEventHandler(MouseEvent.MOUSE_CLICKED,
                new EventHandler<MouseEvent>() {
                    @Override public void handle(MouseEvent e) {
                        Main.model.setSelectedMode("hard");
                    }
                });
        toolBar.getItems().add(redButton);

        toolBar.getItems().add(new Separator());

        ToggleGroup group2 = new ToggleGroup();

        // Restart BUTTON
        Button restartButton = new Button("RESTART");
        restartButton.setTooltip(new Tooltip("Restart the game"));
        restartButton.addEventHandler(MouseEvent.MOUSE_CLICKED,
                new EventHandler<MouseEvent>() {
                    @Override public void handle(MouseEvent e) {
                        System.out.println("Restarting game");
                        Main.model.initializeGame();
                    }
                });
        toolBar.getItems().add(restartButton);

        // QUIT BUTTON
        Button quitButton = new Button("QUIT");
        quitButton.setTooltip(new Tooltip("Quit the game"));
        quitButton.addEventHandler(MouseEvent.MOUSE_CLICKED,
                new EventHandler<MouseEvent>() {
                    @Override public void handle(MouseEvent e) {
                        System.out.println("quitting game");
                        if (Main.model.getMiceRemaining() > 0) {
                            Main.model.setLost(true);
                        }
                        Main.model.showCredits();
                    }
                });
        toolBar.getItems().add(quitButton);

        // HELP MENU
        Menu helpMenu = new Menu("Help");
        MenuItem helpItem = new MenuItem("Help Screen");
        MenuItem aboutItem = new MenuItem("About");

        aboutItem.setOnAction(e -> {
            System.out.println("About item selected");
            Alert alert = new Alert(Alert.AlertType.INFORMATION);
            alert.setTitle("About KvP");
            alert.setHeaderText("About KvP");
            alert.setContentText("Puppies vs. Kittens v0.2");
            alert.showAndWait();
        });

        helpItem.setOnAction(e -> {
            System.out.println("Help Item selected");
            Alert alert = new Alert(Alert.AlertType.INFORMATION);
            alert.setTitle("KvP Help");
            alert.setHeaderText("KvP Help");
            alert.setContentText("To win the game kill all the mice and avoid all the puppies.\n\nPress Arrow keys to move L/R/U/D\nHit space when front paw close to a mouse to kill" +
                    "'.");
            alert.showAndWait();
        });

        helpMenu.getItems().add(helpItem);
        helpMenu.getItems().add(aboutItem);

        MenuBar menuBar = new MenuBar();
        menuBar.getMenus().add(helpMenu);

        toolBar.getItems().add(menuBar);

        VBox vBox = new VBox(toolBar);
        vBox.setPrefWidth(500);

        // add the toolbar to the view
        getChildren().add(vBox);
    }

    private void drawSplash() {
        GraphicsContext g = canvas.getGraphicsContext2D();
        g.drawImage(splashScreen.getImage(), 30, 60);

        Rectangle r = new Rectangle(250, 250, 100, 50);
        r.setFill(Color.ROYALBLUE);
        Label ok = new Label("PLAY NOW");
        ok.setTextFill(Color.WHITE);
        ok.setFont(new Font("Times", 18));
        ok.setMinWidth(100);
        ok.setMinHeight(50);
        ok.setAlignment(Pos.CENTER);
        StackPane p = new StackPane(r, ok);
        p.setLayoutX(250);
        p.setLayoutY(250);
        getChildren().add(p);
    }

        //draw all mice.
        private void drawMice() {
            GraphicsContext g = canvas.getGraphicsContext2D();
            for (Mouse m : Main.model.mouseListProperty().get()) {
                double x = m.x.get();
                double y = m.y.get();
                if (m.dead.get() == false) {
                    if (m.fighting.get() == true) {
                        g.drawImage(altMouseImageView.getImage(), x, y);
                    } else {
                        g.drawImage(mouseImageView.getImage(), x, y);
                    }
                }
            }
        }

    //draw all kittens.
    private void drawKittens() {
        GraphicsContext g = canvas.getGraphicsContext2D();
        for (Kitten k : Main.model.kittenListProperty().get()) {
            double x = k.x.get();
            double y = k.y.get();
            if (Main.model.lost()) {
              g.drawImage(kittenDeadImageView.getImage(),x,y);
            } else if (k.fighting.get() == true) {
                g.drawImage(altKittenImageView.getImage(),x,y);
            } else {
                g.drawImage(kittenImageView.getImage(), x, y);
            }

            // draw kitten hitpoints
            Double hpWidthFactor = (Main.model.getHP()/100.0) * 100.0;
            g.setFill(Color.RED);
            g.fillRect(x,y, 100, 20);
            g.setFill(Color.GREEN);
            g.fillRect(x,y,hpWidthFactor, 20);
        }
    }

    //draw all kittens.
    private void drawPuppies() {
        GraphicsContext g = canvas.getGraphicsContext2D();
        for (Puppy p : Main.model.puppyListProperty().get()) {
            double x = p.x.get();
            double y = p.y.get();
            if (p.fighting.get() == true) {
                g.drawImage(altPuppyImageView.getImage(),x,y);
            } else {
                g.drawImage(puppyImageView.getImage(), x, y);
            }
        }
    }

    private void drawScore() {
        if (!Main.model.finished()) {
            GraphicsContext g = canvas.getGraphicsContext2D();
            g.setFont(new Font("Times", 14));
            g.setFill(Color.BLACK);
            g.setStroke(Color.BLACK);
            g.strokeText("Kills: " + Main.model.getKills().toString(), 300, 50);
            g.strokeText("Mice Left: " + Main.model.getMiceRemaining().toString(), 200, 50);
        }
    }

    private void drawCredits() {
        if (Main.model.finished() == true) {
            Integer timeSpentPlaying = Main.model.getTotalGameTime();
            if (Main.model.getClockTime() > Main.model.getTotalGameTime()) {
                timeSpentPlaying = Main.model.getClockTime();
            }

            String finalScore = ("Kills: " + Main.model.getKills().toString() + "\n");
            finalScore += "Time spent: " + Main.model.getClockTime().toString() + "\n";
            finalScore += "Total time: " + timeSpentPlaying + "\n";

            GraphicsContext g = canvas.getGraphicsContext2D();
            g.setFont(new Font("arial", 33));
            g.setFill(Color.ROYALBLUE);
            g.fillText(finalScore,33, 200);

            g.setFill(Color.ORANGERED);
            if (Main.model.lost()) {
                g.fillText("You lost!", 33, 99);
            } else {
                g.fillText("You won!", 33, 99);
            }
        }
    }

    @Override
        public void layoutChildren() {
            canvas.setWidth(this.getWidth());
            canvas.setHeight(this.getHeight());
            GraphicsContext g = canvas.getGraphicsContext2D();
            g.clearRect(0,0, this.getWidth(), this.getHeight());
            drawMice();
            drawKittens();
            drawPuppies();
            drawScore();
            drawCredits();
            // Show splash screen using FXML
//            if (Main.model.getShowSplash()) {
//                drawSplash();
//            }
        }
}