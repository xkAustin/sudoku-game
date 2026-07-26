# macOS

## Prerequisites

Godot 4.7.1、macOS Universal 模板、Xcode Command Line Tools。公开发布需要
Apple Developer、Developer ID Application 和公证凭据。

## Install Dependencies

安装 Godot、匹配导出模板及 `xcode-select --install`。

## Configuration

预设：`macOS`；架构：arm64+x86_64。开发包可 ad-hoc；正式包配置 Developer ID。

## Build Command

```sh
godot --headless --path . --export-debug "macOS" "build/macos/Sudoku Game.app"
godot --headless --path . --export-release "macOS" "build/macos/Sudoku Game.app"
```

## Output Location

`build/macos/Sudoku Game.app`。

## Run Instructions

```sh
open "build/macos/Sudoku Game.app"
```

## Troubleshooting

ad-hoc/未公证下载可能被 Gatekeeper 阻止。开发者可右键“打开”；面向用户的
正确方案是 Developer ID 签名、`notarytool` 公证和 `stapler`。不要要求用户
全局禁用 Gatekeeper。
