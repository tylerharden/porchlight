mod config;
mod model;
mod scanner;
mod state;
mod tui;

use clap::{Parser, Subcommand};
use config::Config;
use model::{ServerGroup, ServerGroups};
use state::StateError;

#[derive(Parser)]
#[command(name = "porchlight")]
#[command(about = "Find the servers you left on.")]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// List local servers.
    List {
        /// Print machine-readable JSON.
        #[arg(long)]
        json: bool,
    },
    /// Show configuration.
    Config {
        #[command(subcommand)]
        command: ConfigCommands,
    },
    /// Manage server groups.
    Groups {
        #[command(subcommand)]
        command: GroupCommands,
    },
    /// Kill active server processes by port or server id.
    Kill {
        /// Port number or server id from `porchlight list --json`.
        target: String,
    },
    /// Remove a server from recents and pins.
    Remove {
        /// Port number or server id from `porchlight list --json`.
        target: String,
    },
    /// Pin a server so it remains visible when stopped.
    Pin {
        /// Port number or server id from `porchlight list --json`.
        target: String,
    },
    /// Unpin a server.
    Unpin {
        /// Port number or server id from `porchlight list --json`.
        target: String,
    },
    /// Open the interactive terminal UI.
    Tui,
}

#[derive(Subcommand)]
enum ConfigCommands {
    /// Show the effective configuration.
    Show,
}

#[derive(Subcommand)]
enum GroupCommands {
    /// List configured groups.
    List {
        /// Print machine-readable JSON.
        #[arg(long)]
        json: bool,
    },
    /// Add a server group.
    Add {
        /// Display name for the group.
        name: String,
        /// Stable id. Defaults to a slug made from the name.
        #[arg(long)]
        id: Option<String>,
        /// Hex colour, for example #7C5CFF.
        #[arg(long, default_value = "#7C5CFF")]
        color: String,
        /// Icon path or URL. If omitted, Porchlight tries common project favicons.
        #[arg(long)]
        icon: Option<String>,
        /// Command substring to match. Repeat for multiple terms.
        #[arg(long = "command")]
        command_contains: Vec<String>,
        /// Working directory substring/path to match. Repeat for multiple paths.
        #[arg(long = "path")]
        working_directories: Vec<String>,
        /// Higher priority wins when multiple groups match.
        #[arg(long, default_value_t = 0)]
        priority: i32,
    },
    /// Edit a server group.
    Edit {
        /// Group id or exact group name.
        target: String,
        #[arg(long)]
        name: Option<String>,
        #[arg(long)]
        color: Option<String>,
        /// Icon path or URL. Use an empty string to clear.
        #[arg(long)]
        icon: Option<String>,
        /// Replace command substring rules. Repeat for multiple terms.
        #[arg(long = "command")]
        command_contains: Vec<String>,
        /// Replace working directory rules. Repeat for multiple paths.
        #[arg(long = "path")]
        working_directories: Vec<String>,
        #[arg(long)]
        priority: Option<i32>,
    },
    /// Remove a server group.
    Remove {
        /// Group id or exact group name.
        target: String,
    },
}

fn main() {
    if let Err(error) = run() {
        eprintln!("porchlight: {error}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), PorchlightError> {
    let cli = Cli::parse();
    let config = Config::default();

    match cli.command.unwrap_or(Commands::List { json: false }) {
        Commands::List { json } => {
            let active_servers = scanner::scan(&config)?;
            let mut state = state::AppState::load()?;
            let servers = state.merge_servers(active_servers, &config);
            state.save()?;

            if json {
                let response = model::ServerList { servers };
                println!(
                    "{}",
                    serde_json::to_string_pretty(&response).expect("server list serializes")
                );
            } else if servers.is_empty() {
                println!("No local servers found.");
            } else {
                for server in servers {
                    let path = server
                        .display_directory
                        .as_deref()
                        .unwrap_or("Unknown directory");
                    println!(
                        "{}\t{}\t{}\tpid {}\t{}",
                        server.port, server.server_type, server.process_name, server.pid, path
                    );
                }
            }
        }
        Commands::Config { command } => match command {
            ConfigCommands::Show => {
                println!(
                    "{}",
                    serde_json::to_string_pretty(&config).expect("config serializes")
                );
            }
        },
        Commands::Groups { command } => handle_group_command(command)?,
        Commands::Kill { target } => {
            let killed = kill_matching_servers(&config, &target)?;
            println!(
                "Killed {} process{}.",
                killed,
                if killed == 1 { "" } else { "es" }
            );
        }
        Commands::Remove { target } => {
            let mut state = state::AppState::load()?;
            let removed = state.remove(&target);
            state.save()?;
            println!(
                "Removed {} server{}.",
                removed,
                if removed == 1 { "" } else { "s" }
            );
        }
        Commands::Pin { target } => {
            let mut state = state::AppState::load()?;
            let changed = state.set_pinned(&target, true);
            state.save()?;
            println!(
                "{}",
                if changed {
                    "Pinned."
                } else {
                    "No matching server to pin."
                }
            );
        }
        Commands::Unpin { target } => {
            let mut state = state::AppState::load()?;
            let changed = state.set_pinned(&target, false);
            state.save()?;
            println!(
                "{}",
                if changed {
                    "Unpinned."
                } else {
                    "No matching server to unpin."
                }
            );
        }
        Commands::Tui => tui::run(config)?,
    }

    Ok(())
}

fn handle_group_command(command: GroupCommands) -> Result<(), PorchlightError> {
    match command {
        GroupCommands::List { json } => {
            let groups = model::load_server_groups();
            if json {
                println!(
                    "{}",
                    serde_json::to_string_pretty(&groups).expect("server groups serialize")
                );
            } else if groups.groups.is_empty() {
                println!("No groups configured.");
            } else {
                for group in groups.groups {
                    println!(
                        "{}\t{}\t{}\ticon {}\tpriority {}\tcommands [{}]\tpaths [{}]",
                        group.id,
                        group.name,
                        group.color,
                        group.icon.as_deref().unwrap_or("auto"),
                        group.priority,
                        group.command_contains.join(", "),
                        group.working_directories.join(", ")
                    );
                }
            }
        }
        GroupCommands::Add {
            name,
            id,
            color,
            icon,
            command_contains,
            working_directories,
            priority,
        } => {
            let mut groups = model::load_server_groups();
            let id = id.unwrap_or_else(|| slugify(&name));
            if id.is_empty() {
                return Err(PorchlightError::InvalidGroup(
                    "group id cannot be empty".into(),
                ));
            }
            if groups.groups.iter().any(|group| group.id == id) {
                return Err(PorchlightError::InvalidGroup(format!(
                    "group id '{id}' already exists"
                )));
            }

            groups.groups.push(ServerGroup {
                id: id.clone(),
                name,
                color,
                icon: normalize_icon(icon),
                command_contains,
                working_directories,
                priority,
            });
            save_groups(&groups)?;
            println!("Added group {id}.");
        }
        GroupCommands::Edit {
            target,
            name,
            color,
            icon,
            command_contains,
            working_directories,
            priority,
        } => {
            let mut groups = model::load_server_groups();
            let group = find_group_mut(&mut groups, &target)?;
            if let Some(name) = name {
                group.name = name;
            }
            if let Some(color) = color {
                group.color = color;
            }
            if let Some(icon) = icon {
                group.icon = normalize_icon(Some(icon));
            }
            if !command_contains.is_empty() {
                group.command_contains = command_contains;
            }
            if !working_directories.is_empty() {
                group.working_directories = working_directories;
            }
            if let Some(priority) = priority {
                group.priority = priority;
            }
            let id = group.id.clone();
            save_groups(&groups)?;
            println!("Updated group {id}.");
        }
        GroupCommands::Remove { target } => {
            let mut groups = model::load_server_groups();
            let before = groups.groups.len();
            groups
                .groups
                .retain(|group| group.id != target && group.name != target);
            let removed = before - groups.groups.len();
            save_groups(&groups)?;
            println!(
                "Removed {} group{}.",
                removed,
                if removed == 1 { "" } else { "s" }
            );
        }
    }

    Ok(())
}

fn find_group_mut<'a>(
    groups: &'a mut ServerGroups,
    target: &str,
) -> Result<&'a mut ServerGroup, PorchlightError> {
    groups
        .groups
        .iter_mut()
        .find(|group| group.id == target || group.name == target)
        .ok_or_else(|| PorchlightError::NoMatchingGroup(target.to_string()))
}

fn save_groups(groups: &ServerGroups) -> Result<(), PorchlightError> {
    model::save_server_groups(groups).map_err(|source| PorchlightError::GroupSaveFailed {
        path: model::server_groups_path().display().to_string(),
        source,
    })
}

fn slugify(value: &str) -> String {
    value
        .trim()
        .to_lowercase()
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() {
                character
            } else {
                '-'
            }
        })
        .collect::<String>()
        .split('-')
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}

fn normalize_icon(icon: Option<String>) -> Option<String> {
    icon.map(|icon| icon.trim().to_string())
        .filter(|icon| !icon.is_empty())
}

fn kill_matching_servers(config: &Config, target: &str) -> Result<usize, PorchlightError> {
    let active_servers = scanner::scan(config)?;
    let target_port = target.parse::<u16>().ok();
    let matching_servers = active_servers
        .into_iter()
        .filter(|server| target_port == Some(server.port) || server.id == target)
        .collect::<Vec<_>>();

    if matching_servers.is_empty() {
        return Err(PorchlightError::NoMatchingServer(target.to_string()));
    }

    let mut killed_pids = std::collections::HashSet::new();

    for server in matching_servers {
        if server.pid == 0 || !killed_pids.insert(server.pid) {
            continue;
        }

        let status = std::process::Command::new("/bin/kill")
            .arg(server.pid.to_string())
            .status()
            .map_err(|source| PorchlightError::KillFailed {
                pid: server.pid,
                message: source.to_string(),
            })?;

        if !status.success() {
            return Err(PorchlightError::KillFailed {
                pid: server.pid,
                message: status.to_string(),
            });
        }
    }

    Ok(killed_pids.len())
}

#[derive(Debug, thiserror::Error)]
enum PorchlightError {
    #[error(transparent)]
    Scanner(#[from] scanner::ScannerError),
    #[error(transparent)]
    State(#[from] StateError),
    #[error(transparent)]
    Tui(#[from] tui::TuiError),
    #[error("invalid group: {0}")]
    InvalidGroup(String),
    #[error("no group matched '{0}'")]
    NoMatchingGroup(String),
    #[error("failed to save groups to {path}: {source}")]
    GroupSaveFailed {
        path: String,
        source: std::io::Error,
    },
    #[error("no active server matched '{0}'")]
    NoMatchingServer(String),
    #[error("failed to kill pid {pid}: {message}")]
    KillFailed { pid: u32, message: String },
}
