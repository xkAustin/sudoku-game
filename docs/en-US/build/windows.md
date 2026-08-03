# Windows

## Prerequisites

Godot 4.7.1 and the Windows x86_64 export template. An Authenticode certificate
is optional for public distribution.

## Install Dependencies

Install Godot and matching templates. Final QA requires Windows 10 or 11.

## Configuration

Preset: `Windows`; architecture: x86_64; package identifier:
`io.github.xkaustin.sudokugame`.

## Build Command

```sh
godot --headless --path . --export-debug "Windows" build/windows/SudokuGame.exe
godot --headless --path . --export-release "Windows" build/windows/SudokuGame.exe
```

## Output Location

`build/windows/SudokuGame.exe`, `SudokuGame.pck`, and the console wrapper.

## Run Instructions

Keep the EXE, PCK, and wrapper in one directory and run `SudokuGame.exe`.

## Troubleshooting

Re-export the complete directory when the PCK is missing. SmartScreen warnings
require Authenticode signing. Validate windows, shortcuts, and the file picker
at 125%–200% DPI.
