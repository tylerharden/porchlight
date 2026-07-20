# Porchlight CLI

The Porchlight CLI is the source of truth for local server discovery, server state, grouping/classification, and JSON consumed by native apps.

## Commands

```bash
porchlight list
porchlight list --json
porchlight list --json --no-auto-groups
porchlight tui
porchlight groups list
porchlight groups add Frontend --command vite --command npm --color "#7C5CFF" --icon ~/Developer/app/public/favicon.ico --priority 10
porchlight groups edit frontend --name Web --priority 20
porchlight groups remove frontend
porchlight groups summary --json
porchlight groups promote meter-data-tool-poc
porchlight groups hide meter-data-tool-poc
porchlight groups unhide meter-data-tool-poc
porchlight config show
porchlight config set-auto-groups false
porchlight config set-recent-ttl off
porchlight config set-recent-ttl 240
porchlight classify explain <port-or-server-id>
porchlight classify rules
porchlight classify validate-rules
porchlight reset
porchlight kill <port-or-server-id>
porchlight remove <port-or-server-id>
porchlight hide <port-or-server-id>
porchlight unhide <server-identity-key>
porchlight pin <port-or-server-id>
porchlight unpin <port-or-server-id>
```

During development, run through Cargo:

```bash
cargo run -- list
cargo run -- list --json
cargo run -- tui
cargo run -- groups list
cargo run -- config show
cargo run -- classify explain 8000
```

## Architecture

The CLI is split around clear responsibilities:

- `scanner/` discovers active local servers and process metadata.
- `model.rs` defines the stable JSON data returned to apps.
- `classification.rs` owns user-defined Groups, built-in/user classification rules, automatic classification, and icon discovery.
- `state.rs` merges active scans with recent and pinned history.
- `tui.rs` renders the terminal UI over the same server model used by native apps.
- `main.rs` owns CLI argument parsing and command dispatch.

## Terminal UI

`porchlight tui` opens an interactive full-screen terminal view of active and recent servers.

Keybindings:

- `↑` / `↓` or `j` / `k` - select a server
- `enter` or `o` - open the server URL
- `s` - start an inactive server when a start command is known
- `x` - kill an active server
- `p` - pin or unpin the selected server
- `d` - remove the selected recent server
- `r` - refresh now
- `q` or `esc` - quit

## Groups

Groups classify servers without changing their built-in server type. A Group may be user-defined or automatically inferred. Groups are intentionally generic so they can represent dev projects like Alexandria, apps like Plex, service categories like Databases, or local tools. User-defined Groups are stored in `~/.config/porchlight/groups.json` and are shared by the CLI, TUI, and macOS app.

Examples:

```bash
porchlight groups list
porchlight groups list --json
porchlight groups add Frontend --command vite --command npm --color "#7C5CFF" --icon ~/Developer/app/public/favicon.ico --priority 10
porchlight groups add API --path /Users/tyler/Developer/api --color "#34C759"
porchlight groups edit frontend --name Web --priority 20
porchlight groups remove frontend
```

Use repeatable `--command` and `--path` flags for matching rules. If both command and path rules are present, both categories must match. Higher priority wins when multiple groups match. Use `--icon` to set an icon path or file URL; when omitted, Porchlight attempts common web favicon locations such as `public/favicon.ico` and `app/favicon.ico` from the matched working directory.

## JSON Contract

`porchlight list --json` returns:

```json
{
  "servers": [
    {
      "id": "8000:/Users/tyler/Developer/example",
      "port": 8000,
      "pid": 12345,
      "status": "active",
      "process_name": "Python",
      "server_type": "Django",
      "icon": "/Users/tyler/Developer/example/public/favicon.ico",
      "group": {
        "id": "example",
        "name": "Example",
        "kind": "Django",
        "role": "Backend",
        "icon": "/Users/tyler/Developer/example/public/favicon.ico",
        "confidence": 0.73,
        "source": "manage.py + README + process command + server type"
      },
      "command": "python manage.py runserver",
      "working_directory": "/Users/tyler/Developer/example",
      "display_directory": "~/Developer/example",
      "url": "http://localhost:8000",
      "pinned": false,
      "last_seen_at": "2026-07-16T10:00:00Z",
      "start_command": null
    }
  ]
}
```

`group` is present when either a user-defined Group matches or automatic classification has enough local evidence. User-defined Groups take precedence over automatic classification and emit `source: "manual group"`, `confidence: 1.0`, and a `color` when configured.

Use `porchlight list --no-auto-groups` to hide automatically inferred groups while keeping user-defined Groups enabled. The macOS app exposes the same behavior as **Settings > Groups > Show automatic groups**.

## Automatic Classification

Automatic grouping is deterministic, local-only, and explainable. When automatic groups are enabled, classification runs in this order:

- User-defined Groups from `groups.json`.
- Generic worktree-family paths, such as `customer-portal-worktrees/ticket-123` grouping as `Customer Portal`.
- Built-in and user classification rules for service-style processes.
- Metadata fallback from project files and working-directory evidence.

The metadata fallback currently uses evidence from:

- Working directory folder name.
- Worktree-family parent folder names ending in `-worktrees`, `_worktrees`, ` worktrees`, `-worktree`, or `_worktree`.
- README first heading.
- `package.json`, `pyproject.toml`, `Cargo.toml`, and `go.mod` names.
- Framework marker files such as `manage.py`, `next.config.*`, and `vite.config.*`.
- Process command and existing server type inference.
- Common project favicons already discovered for the server.

User-defined Groups take precedence over automatic group data.

The inferred `kind` is a label such as `Django`, `FastAPI`, `Next.js`, `Vite`, `Rust`, `Go`, or eventually `Media Server`. The inferred `role` is a broad UI grouping such as `Backend`, `Frontend`, or `Service`.

For example, these paths share the same automatic group id because the repeated project name appears in the same path position:

```text
~/Developer/ausmusicfinder
~/Developer/ausmusicfinder-worktrees/worktree-1
~/Developer/ausmusicfinder-worktrees/worktree-2
```

The worktree paths classify as `ausmusicfinder` before falling back to the leaf folder name (`worktree-1`) or metadata inside the individual checkout.

Use `porchlight classify explain <port-or-server-id>` to inspect the selected server's group, kind, role, confidence, and source evidence.

Use `porchlight hide <port-or-server-id>` to suppress a specific server from normal lists. Use `porchlight groups hide <group-id>` to suppress every server matching a group. Hidden groups remain visible in `porchlight groups summary --json` with `hidden: true` so they can be shown again with `porchlight groups unhide <group-id>`.

## Classification Rules

Built-in automatic rules live in `src/classification_rules.json`. They cover service-style classifications that are not necessarily software projects, such as Plex, Home Assistant, Postgres, and Redis.

Users can add or override rules with:

```text
~/.config/porchlight/classification_rules.json
```

Shape:

```json
{
  "rules": [
    {
      "id": "plex",
      "name": "Plex",
      "kind": "Media Server",
      "role": "Service",
      "color": "#E5A00D",
      "icon": "/Applications/Plex.app/Contents/Resources/AppIcon.icns",
      "confidence": 0.95,
      "priority": 100,
      "match_any": [
        ["plex media server"],
        ["plexmediaserver"],
        ["plex"]
      ]
    }
  ]
}
```

Rules also accept a top-level JSON array if you prefer to omit the `{ "rules": ... }` wrapper.

Matching behavior:

- `match_any` is a list of term groups.
- A rule matches when any term group fully matches.
- Terms are matched case-insensitively against process name, command, working directory, and server type.
- Higher `priority` wins when multiple rules match.
- A user rule with the same `id` as a built-in rule replaces the built-in rule.

## Server Detection

On macOS, the scanner uses:

- `lsof` to find listening TCP ports.
- `ps` to get process commands.
- process cwd lookup to identify the working directory.

Servers are filtered through default config keywords and excluded patterns in `src/config.rs`.

## Server Types

Built-in server type inference is defined in `src/server_types.json`.

These built-ins identify technology labels such as:

- Django
- Vite
- Next.js
- Rails
- Uvicorn
- Gunicorn
- Python
- Node

User customisation should not modify these built-ins. User-owned classification belongs in Groups.

## Group Configuration

Groups are user-defined labels layered on top of `server_type`. They are stored in:

```text
~/.config/porchlight/groups.json
```

Shape:

```json
{
  "groups": [
    {
      "id": "alexandria",
      "name": "Alexandria",
      "color": "#34C759",
      "icon": "/Users/tyler/Developer/alexandria/public/favicon.ico",
      "command_contains": ["manage.py"],
      "working_directories": ["/Users/tyler/Developer/alexandria"],
      "priority": 100
    }
  ]
}
```

Matching behavior:

- Highest `priority` wins.
- If command rules exist, at least one must match.
- If working-directory rules exist, at least one must match.
- If both categories exist, both categories must match.
- Empty Groups do not match anything.
- Active and inactive/recent servers are re-evaluated against Groups on each list merge.

## State

Runtime state is stored in:

```text
~/.local/state/porchlight/state.json
```

State contains recent and pinned servers. Porchlight keeps the latest 50 recent servers by default; time-based expiry is disabled unless `recent_ttl_minutes` is explicitly configured with `porchlight config set-recent-ttl <minutes>`. Use `porchlight config set-recent-ttl off` to return to count-only history. Writes use unique temporary paths to avoid refresh races between the app window and menu bar polling.

Use `porchlight reset` to remove saved state, config, Groups, and user classification rules. The macOS app exposes the same action in Settings as **Reset Porchlight to Defaults**.

## Tests

```bash
cargo test -j 1
```

Use `-j 1` if the local environment has linker or memory pressure.
