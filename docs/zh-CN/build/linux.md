# Linux

## Prerequisites

Godot 4.7.1、Linux x86_64 模板，以及带 X11 或 Wayland 和音频服务的目标系统。

## Install Dependencies

安装 Godot/模板。发行版通常需要 glibc、X11/Wayland、OpenGL 3.3 兼容驱动和
PipeWire/PulseAudio/ALSA。

## Configuration

预设：`Linux`；架构：x86_64；Compatibility renderer。

## Build Command

```sh
godot --headless --path . --export-debug "Linux" build/linux/sudoku-game.x86_64
godot --headless --path . --export-release "Linux" build/linux/sudoku-game.x86_64
chmod +x build/linux/sudoku-game.x86_64
```

## Output Location

`build/linux/sudoku-game.x86_64` 和 `sudoku-game.pck`。

## Run Instructions

```sh
cd build/linux
./sudoku-game.x86_64
```

## Troubleshooting

保持 PCK 与可执行文件同目录；检查执行位、图形驱动和音频服务。分别在
X11/Wayland、不同缩放和常见 Ubuntu/Fedora/Arch 环境验证。
