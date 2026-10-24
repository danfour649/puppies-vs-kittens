package PuppiesVsKittens;

import javafx.beans.Observable;
import javafx.beans.property.*;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.scene.input.KeyCode;
import javafx.util.Callback;
import java.util.concurrent.ThreadLocalRandom;

import static java.lang.Math.abs;

public class KvPModel {
    private SimpleListProperty<Mouse> mouseListProperty;
    private SimpleListProperty<Kitten> kittenListProperty;
    private SimpleListProperty<Puppy> puppyListProperty;
    private SimpleIntegerProperty kills, miceRemaining, timeTaken, totalPlayTime, clockTime, hp;
    private SimpleBooleanProperty finished, lost, showSplash;
    private SimpleDoubleProperty kittenX, kittenY;
    public static String mode = "easy";

    ObservableList<Mouse> observableMouseList = (ObservableList<Mouse>) FXCollections.observableArrayList(
            new Callback<Mouse, Observable[]>() {
                @Override
                public Observable[] call(Mouse s){
                    return new Observable[]{
                            s.x,
                            s.y,
                            s.fighting,
                            s.dead,
                            s.timeToLiveAfterHurt
                    };
                }
            }
        );

    ObservableList<Kitten> observableKittenList = (ObservableList<Kitten>) FXCollections.observableArrayList(
            new Callback<Kitten, Observable[]>() {
                @Override
                public Observable[] call(Kitten s){
                    return new Observable[]{
                            s.x,
                            s.y,
                            s.fighting,
                            s.dead
                    };
                }
            }
    );

    ObservableList<Puppy> observablePuppyList = (ObservableList<Puppy>) FXCollections.observableArrayList(
            new Callback<Puppy, Observable[]>() {
                @Override
                public Observable[] call(Puppy s){
                    return new Observable[]{
                            s.x,
                            s.y,
                            s.fighting
                    };
                }
            }
    );

    public KvPModel() {
        mouseListProperty = new SimpleListProperty<>(observableMouseList);
        kittenListProperty = new SimpleListProperty<>(observableKittenList);
        puppyListProperty = new SimpleListProperty<>(observablePuppyList);
        kills = new SimpleIntegerProperty(0);
        miceRemaining = new SimpleIntegerProperty(0);
        clockTime = new SimpleIntegerProperty(0);
        timeTaken = new SimpleIntegerProperty(0);
        totalPlayTime = new SimpleIntegerProperty(0);
        finished = new SimpleBooleanProperty(false);
        showSplash = new SimpleBooleanProperty(false);
        lost = new SimpleBooleanProperty(false);
        kittenX = new SimpleDoubleProperty(250);
        kittenY = new SimpleDoubleProperty(250);
        hp = new SimpleIntegerProperty(100);
    }

    // Mouse methods here
    public ListProperty<Mouse> mouseListProperty() {
        return mouseListProperty;
    }
    public Mouse addMouse(double x, double y) {
        Mouse newMouse = new Mouse(x, y);
        mouseListProperty.add(newMouse);
        return newMouse;
    }
    public void initializeMice() {
        int numMice = 7;
        if (mode.equals("medium")) { numMice = 14; }
        if (mode.equals("hard")) { numMice = 21; }
        for (int x= 0; x < numMice; x++) {
            int startX = ThreadLocalRandom.current().nextInt(20, 480);
            int startY = ThreadLocalRandom.current().nextInt(20, 480);
            addMouse(startX, startY);
        }
        miceRemaining.set(numMice);
        finished.set(false);
    }
    public void moveMice() {
        Double mouseSpeed = 2.0;
        if (mode.equals("medium")) { mouseSpeed = 4.0;}
        if (mode.equals("hard")) { mouseSpeed = 6.0;}

        for (Mouse m : mouseListProperty) {
            Double x = m.x.getValue();
            Double y = m.y.getValue();

            if (x < 20 || x > 480 || y < 20 || y > 480 ) {
                // if the mouse is moving out of the frame, spawn him back in the middle
                m.x.set(250);
                m.y.set(250);
            } else {
                m.x.set(x + ThreadLocalRandom.current().nextDouble(-mouseSpeed, mouseSpeed));
                m.y.set(y + ThreadLocalRandom.current().nextDouble(-mouseSpeed, mouseSpeed));
            }
        }
        Main.view.layoutChildren();
    }
    public void unFightMice(Integer clockTime) {
        for (Mouse m: mouseListProperty) {
            if (m.fighting.get() == true && m.dead.get() == false) {
                if (m.timeToLiveAfterHurt.get() > 0) {
                    m.timeToLiveAfterHurt.set(m.timeToLiveAfterHurt.get() - 1);
                } else {
                    m.dead.set(true);
                    kills.set(kills.getValue()+1);
                    miceRemaining.set(miceRemaining.getValue()-1);
                }
            }
        }
        if (miceRemaining.get() < 1) {
            timeTaken.set(clockTime);
            totalPlayTime.set(totalPlayTime.getValue()+clockTime);
            finished.set(true);
        }
    }
    // Kitten methods here
    public ListProperty<Kitten> kittenListProperty() {
        return kittenListProperty;
    }
    public Kitten addKitten(double x, double y) {
        Kitten newKitten = new Kitten(x, y);
        kittenListProperty.add(newKitten);
        return newKitten;
    }
    public void initializeKitten() {
            addKitten(250, 250);
    }
    public void moveKitten(KeyCode direction) {
        for (Kitten k : kittenListProperty) {
            Double x = k.x.getValue();
            Double y = k.y.getValue();

            if (direction.equals(KeyCode.LEFT)) {
                k.x.set(x-33);
            }
            if (direction.equals(KeyCode.RIGHT)) {
                k.x.set(x+33);
            }
            if (direction.equals(KeyCode.UP)) {
                k.y.set(y-33);
            }
            if (direction.equals(KeyCode.DOWN)) {
                k.y.set(y+33);
            }

            kittenX.set(k.x.get());
            kittenY.set(k.y.get());
        }
        Main.view.layoutChildren();
    }
    public void fightKitten() {
        for (Kitten k : kittenListProperty) {
            k.fighting.set(true);
        }
    }
    public void unFightKitten() {
        for (Kitten k : kittenListProperty) {
            if (k.fighting.get() == true) {
                Double x = k.x.get();
                Double y = k.y.get();
                for (Mouse m : mouseListProperty) {
                    // if the cat claw is close enough to the mouse set is as 'fighting'
                    if (abs(m.x.get() - (x+112)) <= 50 && abs(m.y.get() - (y+155)) <=50) {
                        m.fighting.set(true);
                    }
                }
                k.fighting.set(false);
            }
        }
    }
    // Puppy methods here
    public ListProperty<Puppy> puppyListProperty() {
        return puppyListProperty;
    }
    public Puppy addPuppy(double x, double y) {
        Puppy newPuppy = new Puppy(x, y);
        puppyListProperty.add(newPuppy);
        return newPuppy;
    }
    public void initializePuppy() {
        addPuppy(500, 500);
        if (mode.equals("medium")) {
            addPuppy(0, 0);
        }
        if (mode.equals("hard")) {
            addPuppy(0, 0);
            addPuppy(500, 0);
        }
    }
    public void movePuppies() {
        if (!showSplash.get()) {
            Double speed = 150.0;
            Integer puppyIndex = 1;
            if (mode.equals("medium")) {
                speed = 100.0;
            }
            if (mode.equals("hard")) {
                speed = 50.0;
            }
            for (Puppy p : puppyListProperty) {
                Double x = p.x.getValue();
                Double y = p.y.getValue();
                Double distanceX = ((kittenX.get() + 20) - x);
                Double distanceY = ((kittenY.get() + 120) - y);

                if (abs(distanceX) < 33 && abs(distanceY) < 33) {
                    p.fighting.set(true);
                } else {
                    p.fighting.set(false);
                }
                p.x.set(x + ((distanceX * puppyIndex) / speed));
                p.y.set(y + ((distanceY * puppyIndex++) / speed));
            }
            Main.view.layoutChildren();
        }
    }
    public Integer getKills() {
        return kills.get();
    }
    public Integer getMiceRemaining() {
        return miceRemaining.get();
    }
    public boolean finished() {
        return finished.get();
    }
    public void setLost(boolean b) {
        lost.set(b);
    }
    public boolean lost() {
        return lost.get();
    }
    public void setSelectedMode(String s) {
        mode = s;
    }
    public String getSelectedMode() {
        return mode;
    }
    public void showCredits() {
        mouseListProperty.clear();
        // puppyListProperty.clear();
        finished.set(true);
    }

    public void initializeGame() {
        mouseListProperty.clear();
        kittenListProperty.clear();
        puppyListProperty.clear();
        clockTime.set(0);
        lost.set(false);
        finished.set(false);
        hp.set(100);
        initializeMice();
        initializeKitten();
        initializePuppy();
    }

    public Integer getTotalGameTime() {
        return totalPlayTime.get();
    }

    public Integer getClockTime() {
        return clockTime.get();
    }

    public void setClockTime(Integer x) {
        clockTime.setValue(x);
    }

    public void setShowSplash(boolean x) {
        showSplash.setValue(x);
    }

    public boolean getShowSplash() {
        return showSplash.get();
    }

    public SimpleBooleanProperty showSplash() {
        return showSplash;
    }

    public Double getKittenX() {
        return kittenX.get();
    }

    public Double getKittenY() {
        return kittenY.get();
    }

    public void checkFightPuppies() {
        Integer hitStrength = 5;
        if (mode.equals("medium")) { hitStrength = 7; }
        if (mode.equals("hard")) { hitStrength = 20; }

        for (Puppy p : puppyListProperty) {
            if (p.fighting.get()) {
                hp.set(hp.get() - hitStrength);
                // System.out.println("Puppy fighting! Kitten HP: " + hp.get());
                if (hp.get() <= 0) {
                    lost.set(true);
                    finished.set(true);
                }
            }
        }
    }

    public Integer getHP() {
        return hp.get();
    }
}