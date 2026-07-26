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

Current release-output status:

| Platform | Generated output and distribution requirement |
|---|---|
| Windows | CI debug artifact; public release requires Windows QA and optional Authenticode |
| macOS | CI ad-hoc debug app; public release requires Developer ID, notarization and stapling |
| Linux | CI x86_64 debug artifact; public release requires X11/Wayland QA |
| Android | CI debug-signed APK; public release requires a private-keystore APK/AAB |
| iOS | CI unsigned Xcode project; distribution requires Team ID, certificate, profile and Archive/Export |

Generated outputs stay local or in short-lived CI artifacts. Publish selected
release packages through GitHub Releases or platform stores; do not commit them
to the default branch.

Supabase is deployed separately; see the [Supabase guide](SUPABASE_GUIDE.md).
A release may remain fully offline. When the leaderboard is enabled, the client
may contain only a publishable key.
