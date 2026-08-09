# Sudoku Game Open-Source Project

Sudoku Game is an offline-first Godot 4.7.1 application for Android, iOS,
macOS, Windows, and Linux. It requires no account and contains no advertising or
tracking SDK. Network access is used only for the optional leaderboard.

This GitHub repository contains source code, assets, tests, backend migrations,
documentation and reproducible build workflows. It does not track generated
applications or installers on the default branch.

## Option A: download a release

Use [GitHub Releases](https://github.com/xkAustin/sudoku-game/releases) when a
maintainer has published a prebuilt version. Release notes must state platform,
version, checksum, signing status and remaining QA limitations. No installable
iOS IPA is provided without Apple signing.

## Option B: build from source

Install Godot 4.7.1 and its matching export templates, then run:

```sh
./tests/run_all.sh
godot --path .
```

`run_all.sh` serially executes the core tests, development-mode checks, complete
UI smoke flow and Deno backend checks, and exits nonzero if any step fails.

Debug runs open the development launcher; press `F12` for the runtime Debug
panel. See the [Development Mode Guide](DEVELOPMENT_GUIDE.md) for live config
reload, direct settings/leaderboard/test-board entry and release isolation.

For the leaderboard, copy `config/client.env.example` to the ignored
`config/client.env`, add only the project URL and publishable key, and deploy
the migration first.

Local exports belong under the ignored `build/` or `builds/` directories.
Public packages belong in GitHub Releases or platform stores, not the default
branch.

Full documentation:

- [Build overview](BUILD_GUIDE.md)
- [Development Mode](DEVELOPMENT_GUIDE.md)
- [Release deployment](DEPLOYMENT_GUIDE.md)
- [Supabase](SUPABASE_GUIDE.md)
- [Security](SECURITY_GUIDE.md)

Chinese version: [中文文档](../zh-CN/README.md)
