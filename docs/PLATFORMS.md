# Platform support

The project targets Godot 4.7 Stable with the Compatibility renderer. Detailed
requirements, commands, signing guidance and release checks are maintained in
[`BUILD.md`](../BUILD.md).

| Platform | Preset | Architecture | Current status |
|---|---|---|---|
| Android | `Android` | ARM64 | 2026-07-26 debug APK export and v2/v3 signature passed; no connected device; release key and physical-device QA remain |
| iOS | `iOS` | ARM64 + simulator framework | 2026-07-26 unsigned Xcode project export passed with temporary `CIUNSIGNED`; real Team ID, compatible local SDK, signing and device QA remain |
| macOS | `macOS` | Universal | 2026-07-26 ad-hoc debug export, signature check and binary startup passed; Developer ID, notarization and full GUI QA remain |
| Windows | `Windows Desktop` | x86_64 | 2026-07-26 cross-export passed and PE structure verified; Windows runtime QA and optional Authenticode remain |
| Linux | `Linux` | x86_64 | 2026-07-26 cross-export passed and ELF structure verified; Linux X11/Wayland runtime QA remains |

All platforms use the same game core, responsive scenes and versioned `user://`
storage. Keyboard shortcuts adapt to the desktop operating system; all required
game actions also have touch-accessible controls.

The app requests no camera, microphone, location, contacts or advertising
permissions. Android Internet access is retained only for the optional ranked
service. With the public client configuration left blank, the application starts
and remains fully playable offline.

Before a public release, validate startup, menu, generation, input, completion,
online submit/read, safe areas, native file selection, audio, haptics,
background/resume behavior and display scaling on physical target hardware.

The current UI applies the platform-reported display safe area and supports
90%, 100% and 110% interface scaling. Shared headless UI tests cover these code
paths, but cannot prove target-platform windowing, file picker, audio or haptic
behavior. Files under `build/` are ignored. The dated verification directory is
local evidence only and is not a signed release deliverable.
