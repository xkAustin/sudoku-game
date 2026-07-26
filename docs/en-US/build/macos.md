# macOS

## Prerequisites

Godot 4.7.1, the macOS Universal template, and Xcode Command Line Tools. Public
distribution requires Apple Developer, Developer ID Application, and
notarization credentials.

## Install Dependencies

Install Godot, matching templates, and run `xcode-select --install`.

## Configuration

Preset: `macOS`; architectures: arm64+x86_64. Development may use ad-hoc
signing; configure Developer ID for a formal release.

## Build Command

```sh
godot --headless --path . --export-debug "macOS" "build/macos/Sudoku Game.app"
godot --headless --path . --export-release "macOS" "build/macos/Sudoku Game.app"
```

## Output Location

`build/macos/Sudoku Game.app`.

## Run Instructions

```sh
open "build/macos/Sudoku Game.app"
```

## Troubleshooting

Gatekeeper may block ad-hoc or unnotarized downloads. Developers can use
right-click → Open; the correct user-facing solution is Developer ID signing,
`notarytool` notarization, and `stapler`. Do not ask users to disable Gatekeeper
globally.
