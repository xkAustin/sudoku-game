# Android

## Prerequisites

Godot 4.7.1、OpenJDK 17、Android SDK Platform 36、Build-Tools 36.0.0、
Platform-Tools、命令行工具。正式发布需要私有 keystore。

## Install Dependencies

在 Godot Editor Settings 配置 Java SDK 和 Android SDK 路径，并安装匹配
导出模板。Google Play AAB 还需要安装 Godot Android Build Template 并启用
Gradle Build。

## Configuration

预设：`Android`；ARM64；包名 `io.github.xkaustin.sudokugame`；权限仅
`INTERNET`。keystore 路径、alias 和密码只放本地/CI secrets。

## Build Command

```sh
godot --headless --path . --export-debug "Android" build/android/sudoku-game.apk
godot --headless --path . --export-release "Android" build/android/sudoku-game-release.apk
```

## Output Location

`build/android/sudoku-game.apk` 或 release APK/AAB。

## Run Instructions

```sh
adb install -r build/android/sudoku-game.apk
```

## Troubleshooting

用 `sdkmanager --licenses` 接受许可，确认 Java 17、SDK 36 和
`apksigner verify --verbose`。debug 证书不可用于商店更新；release keystore
丢失后无法更新同一签名应用。
