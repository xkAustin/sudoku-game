# Build Guide

The project version is `1.0.0`, the Godot version is `4.7.1.stable`, and the
package identifier is `io.github.xkaustin.sudokugame`. Install export templates
that exactly match the Godot version.

Source builds go to the ignored `build/` directory. Repository delivery
packages are under `builds/`. Before building:

```sh
./tests/run_all.sh
mkdir -p build/android build/ios build/macos build/windows build/linux
```

Platform guides:

- [Windows](build/windows.md)
- [macOS](build/macos.md)
- [Linux](build/linux.md)
- [Android](build/android.md)
- [iOS](build/ios.md)

All presets exclude `backend/`, `tests/`, and `build/`. A local
`config/client.env` may contain public client configuration, but it must never
contain a `service_role` key, password, certificate, or signing key. Before a
formal release, test startup, menu, generation, input, completion, upload, and
leaderboard viewing on the target operating system.

The committed CI pins third-party Actions to immutable commits and verifies
Godot 4.7.1 downloads against the official SHA-512 list. CI outputs remain
unsigned/debug packages and do not replace platform signing or device QA.
