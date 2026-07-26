# Linux

## Prerequisites

Godot 4.7.1, the Linux x86_64 template, and a target with X11 or Wayland plus
audio services.

## Install Dependencies

Install Godot/templates. Typical distributions need glibc, X11/Wayland, an
OpenGL 3.3 compatible driver, and PipeWire/PulseAudio/ALSA.

## Configuration

Preset: `Linux`; architecture: x86_64; Compatibility renderer.

## Build Command

```sh
godot --headless --path . --export-debug "Linux" build/linux/sudoku-game.x86_64
godot --headless --path . --export-release "Linux" build/linux/sudoku-game.x86_64
chmod +x build/linux/sudoku-game.x86_64
```

## Output Location

`build/linux/sudoku-game.x86_64` and `sudoku-game.pck`.

## Run Instructions

```sh
cd build/linux
./sudoku-game.x86_64
```

## Troubleshooting

Keep the PCK beside the executable and check the execute bit, graphics driver,
and audio service. Test X11/Wayland, scaling, and common Ubuntu/Fedora/Arch
environments separately.
