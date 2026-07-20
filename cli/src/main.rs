mod classification;
mod config;
mod model;
mod scanner;
mod state;
mod tui;

use clap::{Parser, Subcommand};
use classification::{ServerGroup, ServerGroups};
use config::Config;
use model::{LocalServer, ServerStatus};
use serde::Serialize;
use state::StateError;
use std::collections::{BTreeMap, BTreeSet};
use std::io::Read as _;

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
        /// Hide automatically inferred groups. User-defined groups still apply.
        #[arg(long = "no-auto-groups")]
        no_auto_groups: bool,
        /// Hide application/background services from app bundles.
        #[arg(long = "no-app-services")]
        no_app_services: bool,
        /// Include hidden servers, marked with hidden: true in JSON output.
        #[arg(long = "include-hidden")]
        include_hidden: bool,
    },
    /// Show configuration.
    Config {
        #[command(subcommand)]
        command: ConfigCommands,
    },
    /// Explain and validate server classification.
    Classify {
        #[command(subcommand)]
        command: ClassifyCommands,
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
    /// Hide a server from normal lists.
    Hide {
        /// Port number, server id, or identity key from `porchlight list --json`.
        target: String,
    },
    /// Show a previously hidden server.
    Unhide {
        /// Server identity key, port, or server id.
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
    /// Reset Porchlight state, config, groups, and user classification rules.
    Reset,
    /// Open the interactive terminal UI.
    Tui,
}

#[derive(Subcommand)]
enum ConfigCommands {
    /// Show the effective configuration.
    Show,
    /// Persist whether automatic groups should be shown by default.
    SetAutoGroups {
        /// true to show automatic groups, false to hide them.
        value: String,
    },
    /// Persist whether application/background services should be shown by default.
    SetAppServices {
        /// true to show app services, false to hide them.
        value: String,
    },
    /// Persist optional time-based recent server expiry. Use "off" for count-only history.
    SetRecentTtl {
        /// Number of minutes, or off to disable time-based expiry.
        value: String,
    },
}

#[derive(Subcommand)]
enum ClassifyCommands {
    /// Explain why a server is grouped. Target is a port or server id.
    Explain {
        /// Port number or server id from `porchlight list --json`.
        target: String,
        /// Print machine-readable JSON.
        #[arg(long)]
        json: bool,
    },
    /// List effective built-in and user classification rules.
    Rules {
        /// Print machine-readable JSON.
        #[arg(long)]
        json: bool,
    },
    /// Validate user classification rules JSON.
    ValidateRules,
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
    /// Replace all groups from JSON on stdin. Used by native apps.
    Replace {
        /// Read a JSON groups document from stdin.
        #[arg(long)]
        stdin: bool,
    },
    /// Summarize configured and discovered groups.
    Summary {
        /// Print machine-readable JSON.
        #[arg(long)]
        json: bool,
    },
    /// Create or update a manual group from a discovered automatic group.
    Promote {
        /// Automatic group id from `porchlight groups summary --json`.
        target: String,
    },
    /// Hide all servers that match a group.
    Hide {
        /// Group id from `porchlight groups summary --json`.
        target: String,
    },
    /// Show servers for a previously hidden group.
    Unhide {
        /// Group id from `porchlight groups summary --json`.
        target: String,
    },
}

#[derive(Debug, Clone, Serialize)]
struct GroupSummaryDocument {
    groups: Vec<GroupSummary>,
}

#[derive(Debug, Clone, Copy)]
struct ServerQueryOptions {
    visible_only: bool,
    include_hidden: bool,
}

impl ServerQueryOptions {
    const ALL: Self = Self {
        visible_only: false,
        include_hidden: false,
    };
    const VISIBLE: Self = Self {
        visible_only: true,
        include_hidden: false,
    };
    const INCLUDE_HIDDEN: Self = Self {
        visible_only: false,
        include_hidden: true,
    };
}

#[derive(Debug, Clone, Serialize)]
struct GroupSummary {
    id: String,
    name: String,
    source: String,
    manual: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    kind: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    role: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    reason: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    color: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    icon: Option<String>,
    active_server_count: usize,
    recent_server_count: usize,
    active_count: u64,
    hidden: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    first_seen_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    last_seen_at: Option<String>,
    ports: Vec<u16>,
    paths: Vec<String>,
}

impl GroupSummary {
    fn manual(group: ServerGroup) -> Self {
        Self {
            id: group.id,
            name: group.name,
            source: "manual".into(),
            manual: true,
            kind: None,
            role: None,
            reason: None,
            color: Some(group.color),
            icon: group.icon,
            active_server_count: 0,
            recent_server_count: 0,
            active_count: 0,
            hidden: false,
            first_seen_at: None,
            last_seen_at: None,
            ports: vec![],
            paths: vec![],
        }
    }

    fn automatic(id: String, name: String) -> Self {
        Self {
            id,
            name,
            source: "automatic".into(),
            manual: false,
            kind: None,
            role: None,
            reason: None,
            color: None,
            icon: None,
            active_server_count: 0,
            recent_server_count: 0,
            active_count: 0,
            hidden: false,
            first_seen_at: None,
            last_seen_at: None,
            ports: vec![],
            paths: vec![],
        }
    }

    fn from_group_match(group: classification::ServerGroupMatch, source: &str) -> Self {
        Self {
            id: group.id,
            name: group.name,
            source: source.into(),
            manual: source == "manual",
            kind: Some(group.kind),
            role: Some(group.role),
            reason: Some(group.source),
            color: group.color,
            icon: group.icon,
            active_server_count: 0,
            recent_server_count: 0,
            active_count: 0,
            hidden: false,
            first_seen_at: None,
            last_seen_at: None,
            ports: vec![],
            paths: vec![],
        }
    }
}

fn main() {
    if let Err(error) = run() {
        eprintln!("porchlight: {error}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), PorchlightError> {
    let cli = Cli::parse();
    let mut config = Config::load()?;

    match cli.command.unwrap_or(Commands::List {
        json: false,
        no_auto_groups: false,
        no_app_services: false,
        include_hidden: false,
    }) {
        Commands::List {
            json,
            no_auto_groups,
            no_app_services,
            include_hidden,
        } => {
            if no_auto_groups {
                config.show_automatic_groups = false;
            }
            if no_app_services {
                config.show_app_services = false;
            }
            let servers = if include_hidden {
                current_servers_including_hidden(&config)?
            } else {
                current_servers(&config)?
            };

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
            ConfigCommands::SetAutoGroups { value } => {
                let value = parse_bool(&value)?;
                Config::set_show_automatic_groups(value)?;
                println!(
                    "Automatic groups {} by default.",
                    if value { "enabled" } else { "disabled" }
                );
            }
            ConfigCommands::SetAppServices { value } => {
                let value = parse_bool(&value)?;
                Config::set_show_app_services(value)?;
                println!(
                    "Application services {} by default.",
                    if value { "shown" } else { "hidden" }
                );
            }
            ConfigCommands::SetRecentTtl { value } => {
                let value = parse_optional_minutes(&value)?;
                Config::set_recent_ttl_minutes(value)?;
                match value {
                    Some(minutes) => println!("Recent servers expire after {minutes} minutes."),
                    None => println!("Recent servers use count-only history."),
                }
            }
        },
        Commands::Classify { command } => handle_classify_command(command, &config)?,
        Commands::Groups { command } => handle_group_command(command, &config)?,
        Commands::Kill { target } => {
            let killed = kill_matching_servers(&config, &target)?;
            println!(
                "Killed {} process{}.",
                killed,
                if killed == 1 { "" } else { "es" }
            );
        }
        Commands::Remove { target } => {
            let removed = update_state(|state| state.remove(&target))?;
            println!(
                "Removed {} server{}.",
                removed,
                if removed == 1 { "" } else { "s" }
            );
        }
        Commands::Hide { target } => {
            let (_, mut state) = current_servers_and_state(&config, ServerQueryOptions::ALL)?;
            let changed = update_loaded_state(&mut state, |state| state.hide_server(&target))?;
            println!(
                "{}",
                if changed {
                    "Hidden."
                } else {
                    "No matching server to hide."
                }
            );
        }
        Commands::Unhide { target } => {
            let changed = update_state(|state| state.unhide_server(&target))?;
            println!(
                "{}",
                if changed {
                    "Unhidden."
                } else {
                    "No matching hidden server."
                }
            );
        }
        Commands::Pin { target } => {
            let changed = update_state(|state| state.set_pinned(&target, true))?;
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
            let changed = update_state(|state| state.set_pinned(&target, false))?;
            println!(
                "{}",
                if changed {
                    "Unpinned."
                } else {
                    "No matching server to unpin."
                }
            );
        }
        Commands::Reset => {
            reset_porchlight()?;
            println!("Reset Porchlight to defaults.");
        }
        Commands::Tui => tui::run(config)?,
    }

    Ok(())
}

fn handle_classify_command(
    command: ClassifyCommands,
    config: &Config,
) -> Result<(), PorchlightError> {
    match command {
        ClassifyCommands::Explain { target, json } => {
            let servers = current_servers_for_explain(config)?;
            let target_port = target.parse::<u16>().ok();
            let server = servers
                .into_iter()
                .find(|server| target_port == Some(server.port) || server.id == target)
                .ok_or_else(|| PorchlightError::NoMatchingServer(target.clone()))?;

            if json {
                println!(
                    "{}",
                    serde_json::to_string_pretty(&server).expect("server serializes")
                );
            } else if let Some(group) = server.group {
                println!(
                    "{}:{}",
                    server.port,
                    server.display_directory.as_deref().unwrap_or("unknown")
                );
                println!("Group: {}", group.name);
                println!("Kind: {}", group.kind);
                println!("Role: {}", group.role);
                println!("Confidence: {:.0}%", group.confidence * 100.0);
                println!("Source: {}", group.source);
            } else {
                println!("No group matched {}.", server.port);
            }
        }
        ClassifyCommands::Rules { json } => {
            let rules = classification::load_classification_rules()?;
            if json {
                println!(
                    "{}",
                    serde_json::to_string_pretty(&rules).expect("classification rules serialize")
                );
            } else if rules.rules.is_empty() {
                println!("No classification rules configured.");
            } else {
                for rule in rules.rules {
                    println!(
                        "{}\t{}\t{}\t{}\tpriority {}\tconfidence {:.0}%",
                        rule.id,
                        rule.name,
                        rule.kind,
                        rule.role,
                        rule.priority,
                        rule.confidence * 100.0
                    );
                }
            }
        }
        ClassifyCommands::ValidateRules => {
            classification::load_classification_rules()?;
            println!("Classification rules are valid.");
        }
    }

    Ok(())
}

fn handle_group_command(command: GroupCommands, config: &Config) -> Result<(), PorchlightError> {
    match command {
        GroupCommands::List { json } => {
            let groups = classification::load_server_groups();
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
            let mut groups = classification::load_server_groups();
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
            let mut groups = classification::load_server_groups();
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
            let mut groups = classification::load_server_groups();
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
        GroupCommands::Replace { stdin } => {
            if !stdin {
                return Err(PorchlightError::InvalidGroup(
                    "groups replace currently requires --stdin".into(),
                ));
            }

            let mut contents = String::new();
            std::io::stdin().read_to_string(&mut contents)?;
            let groups: ServerGroups = serde_json::from_str(&contents)
                .map_err(|source| PorchlightError::InvalidGroup(source.to_string()))?;
            save_groups(&groups)?;
            println!(
                "Replaced {} group{}.",
                groups.groups.len(),
                if groups.groups.len() == 1 { "" } else { "s" }
            );
        }
        GroupCommands::Summary { json } => {
            let groups = group_summary(config)?;
            if json {
                println!(
                    "{}",
                    serde_json::to_string_pretty(&GroupSummaryDocument { groups })
                        .expect("group summary serializes")
                );
            } else if groups.is_empty() {
                println!("No groups found.");
            } else {
                for group in groups {
                    println!(
                        "{}\t{}\t{} active\t{}{}",
                        group.id,
                        group.name,
                        group.active_server_count,
                        group.source,
                        if group.hidden { "\thidden" } else { "" }
                    );
                }
            }
        }
        GroupCommands::Promote { target } => {
            let group = promote_group(config, &target)?;
            println!("Created manual group {}.", group.id);
        }
        GroupCommands::Hide { target } => {
            let changed = update_state(|state| state.hide_group(&target))?;
            println!(
                "{}",
                if changed {
                    "Group hidden."
                } else {
                    "Group was already hidden."
                }
            );
        }
        GroupCommands::Unhide { target } => {
            let changed = update_state(|state| state.unhide_group(&target))?;
            println!(
                "{}",
                if changed {
                    "Group unhidden."
                } else {
                    "Group was not hidden."
                }
            );
        }
    }

    Ok(())
}

fn current_servers(config: &Config) -> Result<Vec<LocalServer>, PorchlightError> {
    Ok(current_servers_and_state(config, ServerQueryOptions::VISIBLE)?.0)
}

fn current_servers_for_explain(config: &Config) -> Result<Vec<LocalServer>, PorchlightError> {
    Ok(current_servers_and_state(config, ServerQueryOptions::ALL)?.0)
}

fn current_servers_including_hidden(config: &Config) -> Result<Vec<LocalServer>, PorchlightError> {
    Ok(current_servers_and_state(config, ServerQueryOptions::INCLUDE_HIDDEN)?.0)
}

fn update_state<T>(update: impl FnOnce(&mut state::AppState) -> T) -> Result<T, PorchlightError> {
    let mut state = state::AppState::load()?;
    update_loaded_state(&mut state, update)
}

fn update_loaded_state<T>(
    state: &mut state::AppState,
    update: impl FnOnce(&mut state::AppState) -> T,
) -> Result<T, PorchlightError> {
    let output = update(state);
    state.save()?;
    Ok(output)
}

fn current_servers_and_state(
    config: &Config,
    options: ServerQueryOptions,
) -> Result<(Vec<LocalServer>, state::AppState), PorchlightError> {
    let active_servers = scanner::scan(config)?;
    let mut state = state::AppState::load()?;
    let servers = state.merge_servers(active_servers, config);
    state.save()?;
    let servers = if options.visible_only || options.include_hidden {
        state.listed_servers(servers, config, options.include_hidden)
    } else {
        servers
    };
    Ok((servers, state))
}

fn group_summary(config: &Config) -> Result<Vec<GroupSummary>, PorchlightError> {
    let manual_groups = classification::load_server_groups().groups;
    let manual_ids = manual_groups
        .iter()
        .map(|group| group.id.clone())
        .collect::<BTreeSet<_>>();
    let (servers, state) = current_servers_and_state(config, ServerQueryOptions::VISIBLE)?;
    let hidden_group_ids = state.hidden_groups.clone();
    let mut summaries = BTreeMap::<String, GroupSummary>::new();

    for group in manual_groups {
        summaries.insert(group.id.clone(), GroupSummary::manual(group));
    }

    for stats in state.group_stats.into_values() {
        if !config.show_app_services && stats.kind == "Application Service" {
            continue;
        }

        let summary = summaries
            .entry(stats.id.clone())
            .or_insert_with(|| GroupSummary::automatic(stats.id.clone(), stats.name.clone()));

        summary.kind = summary.kind.take().or(Some(stats.kind));
        summary.role = summary.role.take().or(Some(stats.role));
        summary.reason = summary.reason.take().or(Some(stats.source));
        summary.color = summary.color.take().or(stats.color);
        summary.icon = summary.icon.take().or(stats.icon);
        summary.active_count = stats.active_count;
        summary.first_seen_at = Some(stats.first_seen_at);
        summary.last_seen_at = Some(stats.last_seen_at);
    }

    for server in servers {
        let Some(group) = server.group.clone() else {
            continue;
        };
        let source = if manual_ids.contains(&group.id) || group.source == "manual group" {
            "manual"
        } else {
            "automatic"
        };
        let summary = summaries
            .entry(group.id.clone())
            .or_insert_with(|| GroupSummary::from_group_match(group.clone(), source));

        summary.color = summary.color.take().or(group.color.clone());
        summary.icon = summary
            .icon
            .take()
            .or_else(|| server.icon.clone())
            .or(group.icon.clone());

        if server.status == ServerStatus::Active {
            summary.active_server_count += 1;
        } else if server.status == ServerStatus::Recent {
            summary.recent_server_count += 1;
        }
        if !summary.ports.contains(&server.port) {
            summary.ports.push(server.port);
        }
        if let Some(path) = server
            .working_directory
            .filter(|path| !path.trim().is_empty() && path != "/")
        {
            if !summary.paths.contains(&path) {
                summary.paths.push(path);
            }
        }
    }

    for (id, summary) in &mut summaries {
        summary.hidden = hidden_group_ids.contains(id);
    }

    let mut groups = summaries.into_values().collect::<Vec<_>>();
    groups.sort_by(|left, right| {
        right
            .manual
            .cmp(&left.manual)
            .then_with(|| left.hidden.cmp(&right.hidden))
            .then_with(|| right.active_server_count.cmp(&left.active_server_count))
            .then_with(|| left.name.cmp(&right.name))
    });
    Ok(groups)
}

fn promote_group(config: &Config, target: &str) -> Result<ServerGroup, PorchlightError> {
    let servers = current_servers_including_hidden(config)?;
    let matching_servers = servers
        .iter()
        .filter(|server| {
            server
                .group
                .as_ref()
                .is_some_and(|group| group.id == target)
        })
        .collect::<Vec<_>>();
    let group_match = matching_servers
        .iter()
        .find_map(|server| server.group.clone())
        .ok_or_else(|| PorchlightError::NoMatchingGroup(target.to_string()))?;

    let mut working_directories = matching_servers
        .iter()
        .filter_map(|server| server.working_directory.clone())
        .filter(|path| !path.trim().is_empty() && path != "/")
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    let mut command_contains = vec![];
    if working_directories.is_empty() {
        command_contains = matching_servers
            .iter()
            .map(|server| server.command.clone())
            .filter(|command| !command.trim().is_empty())
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect();
    }
    working_directories.sort();

    let group = ServerGroup {
        id: group_match.id,
        name: group_match.name,
        color: group_match.color.unwrap_or_else(|| "#34C759".into()),
        icon: group_match.icon,
        command_contains,
        working_directories,
        priority: 100,
    };

    let mut groups = classification::load_server_groups();
    groups.groups.retain(|existing| existing.id != group.id);
    groups.groups.push(group.clone());
    save_groups(&groups)?;
    Ok(group)
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
    classification::save_server_groups(groups).map_err(|source| PorchlightError::GroupSaveFailed {
        path: classification::server_groups_path().display().to_string(),
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

fn parse_bool(value: &str) -> Result<bool, PorchlightError> {
    match value.trim().to_lowercase().as_str() {
        "true" | "yes" | "on" | "1" => Ok(true),
        "false" | "no" | "off" | "0" => Ok(false),
        _ => Err(PorchlightError::InvalidConfig(format!(
            "expected true or false, got '{value}'"
        ))),
    }
}

fn parse_optional_minutes(value: &str) -> Result<Option<u64>, PorchlightError> {
    match value.trim().to_lowercase().as_str() {
        "off" | "none" | "disabled" | "0" => Ok(None),
        value => value.parse::<u64>().map(Some).map_err(|_| {
            PorchlightError::InvalidConfig(format!("expected minutes or off, got '{value}'"))
        }),
    }
}

fn reset_porchlight() -> Result<(), PorchlightError> {
    state::reset_state()?;
    remove_file_if_exists(config::config_path())?;
    remove_file_if_exists(classification::server_groups_path())?;
    remove_file_if_exists(classification::classification_rules_path())?;
    Ok(())
}

fn remove_file_if_exists(path: std::path::PathBuf) -> std::io::Result<()> {
    match std::fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(source) if source.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(source) => Err(source),
    }
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
    #[error(transparent)]
    Config(#[from] config::ConfigError),
    #[error(transparent)]
    Classification(#[from] classification::ClassificationError),
    #[error(transparent)]
    Io(#[from] std::io::Error),
    #[error("invalid group: {0}")]
    InvalidGroup(String),
    #[error("invalid config: {0}")]
    InvalidConfig(String),
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
