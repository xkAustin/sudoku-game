# iOS Build Information

- Version: `1.0.0`
- Attempted: `2026-07-26T05:43:13Z`
- Host: macOS ARM64, Darwin 27.0.0
- Engine: Godot `4.7.1.stable.official.a13da4feb`
- Target: iOS ARM64
- Package: not included
- Signature: Apple signing required
- Network configuration: excluded from the project-only export

Godot successfully produced a local Xcode project from the sanitized source
copy. The generated project was not committed because it is a large,
machine-generated intermediate and cannot produce an installable IPA without an
Apple Developer account, Signing Team, distribution/development certificate,
and matching provisioning profile.

Generate the Xcode project from source with:

```bash
godot --headless --path . --export-release "iOS" build/ios/SudokuGame.ipa
```

With `application/export_project_only` enabled, Godot creates
`build/ios/SudokuGame.xcodeproj` and its frameworks next to the requested
output path. Open that project in Xcode, select the team and profile, run it on
a registered device, and use **Product > Archive** followed by Organizer's
distribution workflow. See the bilingual iOS guides under
`docs/*/build/ios.md`.
