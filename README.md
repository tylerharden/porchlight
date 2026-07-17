# Porchlight

**Find the servers you left on.**

Porchlight is a small developer utility for seeing local servers currently running on your machine, where they came from, and what ports they are using.

The foundation is a fast Rust CLI. Native apps, starting with a macOS menu bar app, sit on top of the CLI by reading stable JSON output.

## Architecture

```text
Rust CLI/core = source of truth
Native apps = thin platform-specific shells over CLI JSON
```

Target layout:

```text
Porchlight/
  cli/
    Cargo.toml
    src/
      main.rs
      model.rs
      config.rs
      scanner/
        mod.rs
        macos.rs
        linux.rs
        windows.rs

  apps/
    macos/
      Porchlight.xcodeproj
      Porchlight/
        SwiftUI menu bar app that shells out to bundled Rust CLI

    windows/
      Future Windows tray/taskbar app

    linux/
      Future tray app if useful

  README.md
  PLAN.md
```

## CLI Direction

Initial commands:

```bash
porchlight list
porchlight list --json
porchlight config show
```

Future commands:

```bash
porchlight pin <server-id>
porchlight unpin <server-id>
porchlight remove <server-id>
porchlight open <server-id-or-port>
porchlight kill <server-id-or-port>
porchlight start <server-id>
```

## macOS App Direction

The macOS app will be a native SwiftUI menu bar app.

The menu bar dropdown shows:

- Active local servers.
- Recent stopped servers.
- Pinned servers.
- Port number.
- Project directory.
- Inferred server type such as `Django`, `Vite`, `Node`, or `Python`.
- Green status light for active servers.
- Grey/off status light for recent or stopped servers.
- Actions such as `Kill`, `Start`, and `Remove`.

Settings opens a native window with a `My Servers` section where users can pin frequently used servers. Pinning should update the menu bar dropdown instantly.

During development, the macOS app calls the local debug CLI binary:

```text
/Users/tyler/Developer/porchlight/cli/target/debug/porchlight
```

Override this path with `PORCHLIGHT_CLI_PATH` if needed.

## Current Status

This repository is being pivoted from an early Swift prototype to the final Porchlight architecture:

- Rust CLI first.
- macOS menu bar app second.
- Windows/Linux support later.

See `PLAN.md` for the detailed implementation plan.

## Development

Run the CLI from the Rust crate:

```bash
cd cli
cargo run -- list
cargo run -- list --json
cargo run -- config show
```

Run tests:

```bash
cd cli
cargo test
```

Run the macOS menu bar app:

```bash
cd apps/macos
DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer" swift run Porchlight
```
