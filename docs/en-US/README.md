# Sudoku Game Delivery

Sudoku Game is an offline-first Godot 4.7.1 application for Android, iOS,
macOS, Windows, and Linux. It requires no account and contains no advertising or
tracking SDK. Network access is used only for the optional leaderboard.

## Option A: use a packaged build

Open `builds/` at the repository root and choose a platform. Each folder has a
`BUILD_INFO.md` with the version, time, environment, SHA-256, and signing state.

- Windows: extract the ZIP and run `SudokuGame.exe`.
- macOS: extract the ZIP and move `Sudoku Game.app` to Applications.
- Linux: extract the `tar.gz` and run `sudoku-game.x86_64`.
- Android: install the debug APK; sign with a private release key before public
  distribution.
- iOS: no installable IPA is committed; sign and archive the Xcode project
  locally as described in the iOS guide.

Packages are generated from a clean source copy without `config/client.env`.
They are therefore offline by default and never commit a real Supabase value.
Choose Option B when the online leaderboard is required.

## Option B: build from source

Install Godot 4.7.1 and its matching export templates, then run:

```sh
./tests/run_all.sh
godot --path .
```

For the leaderboard, copy `config/client.env.example` to the ignored
`config/client.env`, add only the project URL and publishable key, and deploy
the migration first.

Full documentation:

- [Build overview](BUILD_GUIDE.md)
- [Release deployment](DEPLOYMENT_GUIDE.md)
- [Supabase](SUPABASE_GUIDE.md)
- [Security](SECURITY_GUIDE.md)

Chinese version: [中文文档](../zh-CN/README.md)
