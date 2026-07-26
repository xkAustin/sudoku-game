# Release Builds

Version: `1.0.0`
Built: `2026-07-26T05:43:13Z`
Source engine: Godot `4.7.1.stable.official.a13da4feb`

These packages were exported from a sanitized source copy that intentionally
excluded `config/client.env`, `.env` files, local Supabase CLI state, caches,
logs, signing material, and Git metadata. They are therefore safe offline
builds: the game works without a network, while online leaderboard features
remain unavailable until the user builds from source with their own public
Supabase configuration.

| Platform | Package | Signature state |
| --- | --- | --- |
| Windows | `windows/SudokuGame-1.0.0-windows-x86_64.zip` | Unsigned |
| macOS | `macos/SudokuGame-1.0.0-macos-universal.zip` | Ad-hoc signed |
| Linux | `linux/SudokuGame-1.0.0-linux-x86_64.tar.gz` | Unsigned |
| Android | `android/SudokuGame-1.0.0-android-arm64-debug.apk` | Godot debug certificate |
| iOS | No installable package | Apple signing required |

Each platform directory contains a `BUILD_INFO.md` file with its SHA-256
checksum, environment, output details, and remaining signing work. Source-build
instructions are available in [`docs/en-US/BUILD_GUIDE.md`](../docs/en-US/BUILD_GUIDE.md)
and [`docs/zh-CN/BUILD_GUIDE.md`](../docs/zh-CN/BUILD_GUIDE.md).
