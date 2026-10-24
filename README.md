# Puppies vs. Kittens

**v0.2 — the revival**

A tiny hand-drawn JavaFX arcade game. You are the kitten. Hunt down every
mouse on the field — but keep clear of the puppies: they are hunting *you*,
and they fight back.

The art is all hand-drawn, including the splash logo (which still shows the
original v1.0 artwork — some things you do not redraw).

## How to play

- **Arrow keys** — move the kitten (left / right / up / down)
- **Space** — strike, when your front paw is close to a mouse
- Kill all the mice to win. Avoid the puppies.
- **EASY / MEDIUM / HARD** buttons set the difficulty
- **RESTART** starts a fresh game, **QUIT** ends it (quitting with mice
  still on the field counts as a loss)
- The HUD tracks mice left, kills, and time

## Build and run

You need a JDK that bundles JavaFX (for example Azul Zulu FX, JDK 17+),
with JAVA_HOME pointing at it:

    export JAVA_HOME=/path/to/zulu-fx-jdk
    ./build.sh
    java -jar puppies-vs-kittens.jar

build.sh compiles the sources in src/PuppiesVsKittens and packages a
runnable jar in the repo root.

## Layout

- src/PuppiesVsKittens — game sources (model / view / controller) and sprites
- screenshots — the game running again, October 2026

## History

Originally written in 2020 as v1.0 and left in a backup folder. Revived in
2026: recovered from backups, verified compiling and running on a modern
JavaFX JDK, rebranded, and released as v0.2. No changes to gameplay or art.
