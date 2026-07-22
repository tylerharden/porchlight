# Porchlight

[![CLI CI](https://github.com/tylerharden/porchlight/actions/workflows/ci-cli.yml/badge.svg)](https://github.com/tylerharden/porchlight/actions/workflows/ci-cli.yml)
[![macOS CI](https://github.com/tylerharden/porchlight/actions/workflows/ci-macos.yml/badge.svg)](https://github.com/tylerharden/porchlight/actions/workflows/ci-macos.yml)
[![CLI Release](https://github.com/tylerharden/porchlight/actions/workflows/release-cli.yml/badge.svg)](https://github.com/tylerharden/porchlight/actions/workflows/release-cli.yml)
[![macOS Release](https://github.com/tylerharden/porchlight/actions/workflows/release-macos.yml/badge.svg)](https://github.com/tylerharden/porchlight/actions/workflows/release-macos.yml)

**Find the servers you left on.**

Porchlight is a local developer utility for seeing local servers running on your machine, the ports they use, where they came from, and what actions are available.

The Rust CLI is the source of truth. The macOS app shells out to the CLI and reads stable JSON output.

## Download

[![Latest macOS Release](https://img.shields.io/github/v/release/tylerharden/porchlight?filter=macos-v*&label=macOS&color=blue)](https://github.com/tylerharden/porchlight/releases)
[![Latest CLI Release](https://img.shields.io/github/v/release/tylerharden/porchlight?filter=cli-v*&label=CLI&color=orange)](https://github.com/tylerharden/porchlight/releases)

## Current Status

- Rust CLI for macOS server discovery is implemented.
- Native macOS app is implemented as a regular Xcode project.
- Menu bar dropdown uses `NSStatusItem` and `NSMenu`.
- Main window uses native SwiftUI, including split-view Servers and Groups sections.
- Windows/Linux apps are not started.

## Architecture

```text
cli/                 Rust CLI and server detection core
apps/macos/          Native macOS app
PLAN.md              Product/implementation notes
README.md            Project overview
```

The CLI scans local listening processes, enriches them with process metadata, applies user-defined Groups before automatic classification, merges active servers with recent and pinned state, and returns JSON. Native apps should treat that JSON as the app contract.

## Features

- Detect active local development servers on macOS.
- Show port, process, command, working directory, status, and inferred type.
- Infer common server types such as Django, Vite, Next.js, Rails, Uvicorn, Python, and Node.
- Infer groups with name, kind, role, icon, confidence, and source evidence.
- Keep recent stopped servers visible as bounded history.
- Pin servers so they remain visible when stopped.
- Kill, remove, pin, unpin, start, and open servers from the app.
- Create user-defined Groups with colour, priority, command matching, and working-directory matching.
- Section active and inactive/recent servers by Group in the menu bar until they are removed.

## Repository Layout

```text
porchlight/
  cli/
    Cargo.toml
    README.md
    src/
      main.rs
      model.rs
      config.rs
      state.rs
      server_types.json
      scanner/
        mod.rs
        macos.rs

  apps/
    macos/
      README.md
      Porchlight.icon/
      Porchlight.xcodeproj/
      Porchlight/
        App/
        Assets/
        Extensions/
        MainWindow/
        MenuBar/
        Models/
        Services/
        SharedViews/
        ViewModels/
      PorchlightTests/
```

## CLI

Common commands:

```bash
cd cli
cargo run -- list
cargo run -- list --json
cargo run -- config show
cargo run -- kill <port-or-server-id>
cargo run -- remove <port-or-server-id>
cargo run -- pin <port-or-server-id>
cargo run -- unpin <port-or-server-id>
cargo run -- classify explain <port-or-server-id>
cargo run -- config set-recent-ttl off
cargo run -- reset
```

Run tests:

```bash
cd cli
cargo test -j 1
```

See `cli/README.md` for CLI details.

## macOS App

Build with Xcode beta:

```bash
cd apps/macos
DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer" xcodebuild -project "Porchlight.xcodeproj" -scheme "Porchlight" -configuration Debug build
```

Run tests with Xcode beta:

```bash
cd apps/macos
DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer" xcodebuild test -project "Porchlight.xcodeproj" -scheme "Porchlight" -configuration Debug -destination "platform=macOS"
```

The Xcode build bundles the Rust CLI into:

```text
Porchlight.app/Contents/Resources/porchlight
```

During development, the app resolves the CLI in this order:

1. `PORCHLIGHT_CLI_PATH`, if set.
2. Bundled app resource named `porchlight`.
3. Local development binary at `~/Developer/porchlight/cli/target/debug/porchlight`.

The shared GitHub Actions workflow runs `cargo test -j 1` for the CLI and `xcodebuild test` for the macOS app.

See `apps/macos/README.md` for macOS app details.

## User Data

Porchlight stores runtime state and user Groups outside the repo:

```text
~/.local/state/porchlight/state.json
~/.config/porchlight/config.json
~/.config/porchlight/groups.json
~/.config/porchlight/classification_rules.json
```

`state.json` tracks recent and pinned servers. `config.json` stores shared CLI/app defaults such as automatic groups. `groups.json` stores user-defined Groups edited from the macOS app via the CLI. `classification_rules.json` is optional and overrides built-in automatic rules.

## Development Notes

- Keep server detection and JSON shape in the CLI.
- Keep platform UI native-first.
- Do not mutate built-in server type rules for user customisation; use Groups for user-owned classification and explicit grouping overrides.
- macOS sandboxing is disabled so Porchlight can inspect local processes.
