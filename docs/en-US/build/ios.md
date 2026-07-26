# iOS

## Prerequisites

macOS, Godot 4.7.1 iOS templates, Xcode, a usable iOS SDK, Apple Developer
Account, Team ID, signing certificate, and provisioning profile.

## Install Dependencies

Install Xcode/Command Line Tools, accept licenses, and install matching device
or simulator runtimes.

## Configuration

Preset: `iOS`; bundle ID `io.github.xkaustin.sudokugame`; keep
`application/export_project_only=true`. Add the real Team ID locally. Never
commit certificates, profiles, or private keys.

## Build Command

```sh
godot --headless --path . --export-debug "iOS" build/ios/SudokuGame.ipa
open build/ios/SudokuGame.xcodeproj
```

## Output Location

Godot creates `build/ios/SudokuGame.xcodeproj` and frameworks. Xcode
Archive/Export creates the signed IPA.

## Run Instructions

Choose the Signing Team and target device in Xcode, then Build/Run. For release,
use Product → Archive → Distribute App.

## Troubleshooting

An empty Team ID blocks export. A disposable copy may use `CIUNSIGNED` for
project generation only; replace it in Xcode. `No eligible destination` means a
matching runtime/device is unavailable. Final QA must cover safe areas, file
selection, haptics, and background recovery on iPhone/iPad.
