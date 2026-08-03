# Building Sudoku Game

Bilingual build guides:
[中文](docs/zh-CN/BUILD_GUIDE.md) ·
[English](docs/en-US/BUILD_GUIDE.md). Platform-specific prerequisites,
commands, output locations, run steps and troubleshooting live under each
language's `build/` directory.

Sudoku Game targets Godot 4.7 and uses the Compatibility renderer. The same
GDScript project is exported to Android, iOS, macOS, Windows and Linux. Official
Godot 4.7 export templates are required for every platform.

The release identity is:

- Product: `Sudoku Game`
- Package and bundle identifier: `io.github.xkaustin.sudokugame`
- Version: `1.0.0`

## Current verification status

The current working tree was exported with Godot 4.7.1 on 2026-08-03 into the
ignored `build/` directory:

| Platform | Result on this host |
|---|---|
| Android | ARM64 debug APK exported; v2/v3 debug signature verified; no connected device |
| iOS | Unsigned Xcode project exported with temporary `CIUNSIGNED`; Xcode project inspection passed, but iOS 26.5 platform is not installed, so no app/IPA was built |
| macOS | Universal debug and release apps exported, ad-hoc signatures verified, and both binaries launched successfully; the release log contained no Development Mode output |
| Windows | x86_64 debug EXE and PCK exported and PE structure verified; not runnable on this macOS host |
| Linux | x86_64 debug ELF and PCK exported and ELF structure verified; not runnable on this macOS host |

The shared UI suite passed menu, generation, input, completion, ranked upload
choice and cached leaderboard display. The GDScript suite reported 85
assertions and zero failures, the Development Mode smoke suite reported zero
failures, and the local Deno backend suite passed. These checks do not replace
platform-native device QA or confirm the deployed Supabase schema.

The app is offline-first. Online ranking support remains disabled until
`config/client.env` contains the two public client values and the SQL migration
has been applied to the target Supabase project. Never put a Supabase
service-role key, signing password or private certificate in this repository.

## Common preparation

1. Install Godot 4.7 Stable and the matching official export templates.
2. Open the project once so SVG assets are imported.
3. Run the complete test suite:

   ```sh
   ./tests/run_all.sh
   ```

4. Create the required output directories:

   ```sh
   mkdir -p build/android build/ios build/macos build/windows build/linux
   ```

All presets exclude `backend/`, `tests/` and `build/` from the shipped game.
They explicitly include `config/client.env` when it exists because it contains
only a public project URL and publishable client key. Review that file before
every export; a secret or `service_role` key is never valid there.
Signing credentials must be supplied through local Godot editor settings,
environment variables or CI secrets.

## Windows

Requirements:

- Godot 4.7 Windows x86_64 export template
- A Windows machine or compatibility test environment for final QA
- Optional Authenticode certificate for public distribution

Export:

```sh
godot --headless --path . --export-release "Windows" build/windows/SudokuGame.exe
```

The preset exports x86_64 with the Compatibility renderer. Test window resizing,
125–200% display scaling, keyboard shortcuts, imported audio and both light and
dark themes on an actual Windows system. Sign the EXE for public distribution.

## macOS

Requirements:

- Godot 4.7 macOS export template
- Xcode command-line tools
- Apple Developer ID certificate and notarization credentials for distribution

Export:

```sh
godot --headless --path . --export-release "macOS" "build/macos/Sudoku Game.app"
```

The preset creates a Universal application for Intel and Apple Silicon. Local
development builds use ad-hoc signing. Public downloads should use Developer ID
signing, hardened runtime, notarization and stapling. Keep certificate files and
notarization credentials outside the repository.

## Linux

Requirements:

- Godot 4.7 Linux x86_64 export template
- X11 and Wayland environments for final QA

Export:

```sh
godot --headless --path . --export-release "Linux" build/linux/sudoku-game.x86_64
chmod +x build/linux/sudoku-game.x86_64
```

Verify the executable on both X11 and Wayland, including desktop scaling,
keyboard shortcuts, native file selection and audio output. AppImage or Flatpak
packaging can be added after the raw binary has passed runtime testing.

## Android

Requirements on macOS, Windows or Linux:

- OpenJDK 17
- Android SDK Platform-Tools 35.0.0 or later
- Android SDK Build-Tools 36.0.0
- Android SDK Platform 36
- Android SDK Command-line Tools
- A local debug keystore for testing
- A private release keystore for store distribution

Configure the Java SDK and Android SDK paths in Godot Editor Settings. For a
locally signed development APK, run:

```sh
godot --headless --path . --export-debug "Android" build/android/sudoku-game.apk
```

The committed preset uses Godot's prebuilt Android template and is suitable for
device tests. It includes standard, adaptive and monochrome launcher icons. The
installed SDK 36 toolchain is used by the exporter; explicit Min/Target SDK
overrides are only available after enabling a Gradle build.

For an APK distributed outside Google Play, configure a private release
keystore, then run:

```sh
godot --headless --path . --export-release "Android" build/android/sudoku-game-release.apk
```

Google Play requires an AAB: install the Android build template, enable Gradle
Build, select AAB as the export format and export with the release keystore.
Supply keystore values with `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
`GODOT_ANDROID_KEYSTORE_RELEASE_USER` and
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`; never commit them.

Test portrait layout, touch targets, system back behavior, native audio-file
selection and system-governed haptic feedback on physical Android hardware.

## iOS

Requirements:

- macOS with Xcode and the iOS SDK
- Godot 4.7 iOS export template
- Apple Developer account
- A 10-character Apple Team ID
- Signing certificate and provisioning profile

In the iOS preset, set the local Apple Team ID and signing values. Keep
`application/export_project_only` enabled so Godot generates an Xcode project,
then open that project in Xcode to choose the team, build, archive and distribute.
The committed bundle identifier is `io.github.xkaustin.sudokugame`.

The Team ID cannot be completed in this repository because it belongs to the
developer account. Final verification must run on an iPhone and iPad and cover
portrait safe areas, native audio-file selection, device-default haptics,
background/resume behavior and both appearance modes.

Godot requires a syntactically valid Team ID even for project-only export. The
GitHub Actions build replaces the empty value with the explicit non-production
placeholder `CIUNSIGNED` only inside its disposable runner, then uploads the
Xcode project. A real developer must replace it with their Apple Team ID before
building or archiving.

## GitHub Actions

`.github/workflows/test.yml` runs the fast Godot/Deno checks on pushes and pull
requests, and runs the 500-puzzle stress pass on `main`, manual dispatch and the
weekly schedule.

`.github/workflows/build.yml` installs and caches Godot 4.7.1 plus matching
export templates, then produces:

- Android debug APK on Ubuntu with Java 17 and Android SDK 36;
- Linux and Windows debug artifacts on Ubuntu;
- macOS debug app and an unsigned iOS Xcode project on macOS.

Every third-party Action reference is pinned to an immutable commit. Every
downloaded Godot engine/template archive is verified against the official
4.7.1 SHA-512 list before extraction or execution; cache keys are versioned.
Artifacts are retained for 14 days. The workflow intentionally contains no
release signing credentials. Run it from GitHub's Actions page with
`workflow_dispatch`, or by opening a pull request after the files are committed.
The workflow is designed for a clean clone and does not consume committed build
outputs. Its Linux, Windows, Android, macOS and iOS project jobs passed on
2026-07-26. Publish selected, appropriately signed packages through GitHub
Releases or a platform store rather than committing them to the default branch.

## Release checklist

- Tests pass with the same Godot version used for export.
- Version values match in `project.godot`, `config/app_config.gd` and all presets.
- Exported packages contain no tests, backend source or secret keys. The intended
  `config/client.env` public client configuration may be present.
- Windows and macOS artifacts are signed for public distribution.
- Android `version/code` is incremented for each store release.
- iOS build and short versions are incremented for each App Store upload.
- Each artifact is smoke-tested on its target operating system.
