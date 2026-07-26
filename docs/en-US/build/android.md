# Android

## Prerequisites

Godot 4.7.1, OpenJDK 17, Android SDK Platform 36, Build-Tools 36.0.0,
Platform-Tools, and command-line tools. A private keystore is required for
release.

## Install Dependencies

Configure Java SDK and Android SDK paths in Godot Editor Settings and install
matching templates. A Google Play AAB also requires the Godot Android Build
Template with Gradle Build enabled.

## Configuration

Preset: `Android`; ARM64; package `io.github.xkaustin.sudokugame`; only the
`INTERNET` permission. Keep keystore path, alias, and password in local or CI
secret storage.

## Build Command

```sh
godot --headless --path . --export-debug "Android" build/android/sudoku-game.apk
godot --headless --path . --export-release "Android" build/android/sudoku-game-release.apk
```

## Output Location

`build/android/sudoku-game.apk` or a release APK/AAB.

## Run Instructions

```sh
adb install -r build/android/sudoku-game.apk
```

## Troubleshooting

Accept licenses with `sdkmanager --licenses`, verify Java 17 and SDK 36, and run
`apksigner verify --verbose`. A debug certificate cannot support store updates;
losing the release keystore prevents updates to the same signed application.
