# Platform support

The project targets Godot 4.7 Stable with the Compatibility renderer. Detailed
requirements, commands, signing guidance and release checks are maintained in
[`BUILD.md`](../BUILD.md).

| Platform | Preset | Architecture | Current status |
|---|---|---|---|
| Android | `Android` | ARM64 | Debug APK exported and verified; release signing remains |
| iOS | `iOS` | ARM64 | Xcode-project preset ready; Apple Team ID and signing remain |
| macOS | `macOS` | Universal | Local export and runtime verified; distribution signing remains |
| Windows | `Windows Desktop` | x86_64 | Cross-export artifact verified; target-system runtime QA remains |
| Linux | `Linux` | x86_64 | Cross-export artifact verified; X11/Wayland runtime QA remains |

All platforms use the same game core, responsive scenes and versioned `user://`
storage. Keyboard shortcuts adapt to the desktop operating system; all required
game actions also have touch-accessible controls.

The app requests no camera, microphone, location, contacts or advertising
permissions. Android Internet access is retained only for the optional ranked
service. With the public client configuration left blank, the application starts
and remains fully playable offline.

Before a public release, validate safe areas, native file selection, audio,
haptics, background/resume behavior and display scaling on physical target
hardware.
