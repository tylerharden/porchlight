# Porchlight CLI

The Porchlight CLI is the source of truth for local server discovery, server state, and JSON consumed by native apps.

## Commands

```bash
porchlight list
porchlight list --json
porchlight config show
porchlight kill <port-or-server-id>
porchlight remove <port-or-server-id>
porchlight pin <port-or-server-id>
porchlight unpin <port-or-server-id>
```

During development, run through Cargo:

```bash
cargo run -- list
cargo run -- list --json
cargo run -- config show
```

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
      "group": {
        "id": "...",
        "name": "Alexandria",
        "color": "#34C759"
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

`group` is omitted when no user Group matches.

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

## Groups

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

State contains recent and pinned servers. Writes use unique temporary paths to avoid refresh races between the app window and menu bar polling.

## Tests

```bash
cargo test -j 1
```

Use `-j 1` if the local environment has linker or memory pressure.
