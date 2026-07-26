# Release Deployment Guide

1. Keep the version synchronized in `project.godot`,
   `config/app_config.gd`, and `export_presets.cfg`.
2. Run fast, stress, UI, and—when applicable—Supabase tests.
3. Build from a clean source copy and scan packages for keys and signing
   material.
4. Sign with private platform credentials that never enter the repository.
5. Run full target-device QA and record SHA-256 hashes.
6. Upload to a GitHub Release or store; do not give private signing keys to
   ordinary CI jobs.

Current repository delivery status:

| Platform | Repository delivery |
|---|---|
| Windows | Unsigned ZIP; requires Windows QA, optional Authenticode |
| macOS | Ad-hoc Universal ZIP; requires Developer ID, notarization and stapling |
| Linux | Unsigned x86_64 tar.gz; requires X11/Wayland QA |
| Android | Debug-signed APK; requires a private-keystore release APK/AAB |
| iOS | Documentation only; requires Team ID, certificate, profile, Archive/Export |

Supabase is deployed separately; see the [Supabase guide](SUPABASE_GUIDE.md).
A release may remain fully offline. When the leaderboard is enabled, the client
may contain only a publishable key.
