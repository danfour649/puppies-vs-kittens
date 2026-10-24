#!/usr/bin/env bash
set -euo pipefail
JAVA_HOME="${JAVA_HOME:?Set JAVA_HOME to a JDK that bundles JavaFX (e.g. Azul Zulu FX)}"
export PATH="$JAVA_HOME/bin:$PATH"
rm -rf out
mkdir -p out
javac -d out $(find src -name "*.java")
cp src/PuppiesVsKittens/*.png src/PuppiesVsKittens/*.fxml out/PuppiesVsKittens/
jar cfe puppies-vs-kittens.jar PuppiesVsKittens.Main -C out .
echo "Built puppies-vs-kittens.jar — run it with: java -jar puppies-vs-kittens.jar"
