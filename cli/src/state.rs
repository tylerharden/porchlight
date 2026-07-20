use crate::classification::infer_server_group;
use crate::config::Config;
use crate::model::{LocalServer, ServerStatus};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::io;
use std::path::PathBuf;
use time::{Duration, OffsetDateTime};

const MAX_RECENT_SERVERS: usize = 50;

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct AppState {
    #[serde(default)]
    pub recent_servers: Vec<LocalServer>,
    #[serde(default)]
    pub pinned_servers: Vec<LocalServer>,
    #[serde(default)]
    pub group_stats: HashMap<String, GroupStats>,
    #[serde(default)]
    pub hidden_servers: HashSet<String>,
    #[serde(default)]
    pub hidden_groups: HashSet<String>,
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct GroupStats {
    pub id: String,
    pub name: String,
    pub kind: String,
    pub role: String,
    pub source: String,
    #[serde(default)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub color: Option<String>,
    #[serde(default)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
    pub first_seen_at: String,
    pub last_seen_at: String,
    pub active_count: u64,
}

impl AppState {
    pub fn load() -> Result<Self, StateError> {
        let path = state_path();

        if !path.exists() {
            return Ok(Self::default());
        }

        let data = match fs::read_to_string(&path) {
            Ok(data) => data,
            Err(source) if source.kind() == io::ErrorKind::NotFound => return Ok(Self::default()),
            Err(source) => return Err(StateError::Read { path, source }),
        };
        serde_json::from_str(&data).map_err(StateError::Parse)
    }

    pub fn save(&self) -> Result<(), StateError> {
        let path = state_path();

        ensure_parent_directory(&path)?;

        let temporary_path = temporary_state_path(&path);
        let data = serde_json::to_string_pretty(self).expect("state serializes");
        ensure_parent_directory(&temporary_path)?;
        fs::write(&temporary_path, data).map_err(|source| StateError::Write {
            path: temporary_path.clone(),
            source,
        })?;

        match fs::rename(&temporary_path, &path) {
            Ok(()) => {}
            Err(source) if source.kind() == io::ErrorKind::NotFound => {
                ensure_parent_directory(&path)?;
                fs::rename(&temporary_path, &path).map_err(|source| StateError::Rename {
                    from: temporary_path,
                    to: path,
                    source,
                })?;
            }
            Err(source) => {
                return Err(StateError::Rename {
                    from: temporary_path,
                    to: path,
                    source,
                });
            }
        }

        Ok(())
    }

    pub fn merge_servers(
        &mut self,
        mut active_servers: Vec<LocalServer>,
        config: &Config,
    ) -> Vec<LocalServer> {
        let now = OffsetDateTime::now_utc();
        let now_text = format_timestamp(now);

        let previous_recent_servers = std::mem::take(&mut self.recent_servers);
        let previous_active_keys = previous_recent_servers
            .iter()
            .filter(|server| server.status == ServerStatus::Active)
            .map(server_identity_key)
            .collect::<HashSet<_>>();
        backfill_unknown_active_locations(&mut active_servers, &previous_recent_servers);

        let active_keys = active_servers
            .iter()
            .map(server_identity_key)
            .collect::<HashSet<_>>();

        let recent_by_key = previous_recent_servers
            .into_iter()
            .map(|server| (server_identity_key(&server), server))
            .collect::<HashMap<_, _>>();

        let mut output = active_servers
            .into_iter()
            .map(|mut server| {
                let previous = recent_by_key.get(&server_identity_key(&server));
                server.status = ServerStatus::Active;
                server.last_seen_at = Some(now_text.clone());
                server.pinned = previous
                    .map(|server| server.pinned)
                    .unwrap_or(server.pinned);
                server.start_command = server
                    .start_command
                    .or_else(|| previous.and_then(|server| server.start_command.clone()));
                server.icon = server
                    .icon
                    .or_else(|| previous.and_then(|server| server.icon.clone()));
                server.group = server
                    .group
                    .or_else(|| previous.and_then(|server| server.group.clone()));
                server
            })
            .collect::<Vec<_>>();

        if config.show_recents {
            let mut stopped_recents = recent_by_key
                .into_values()
                .filter(|server| !active_keys.contains(&server_identity_key(server)))
                .filter(|server| {
                    config
                        .recent_ttl_minutes
                        .map(|minutes| {
                            recent_is_fresh(server, now - Duration::minutes(minutes as i64))
                                || server.pinned
                        })
                        .unwrap_or(true)
                })
                .map(|mut server| {
                    server.status = ServerStatus::Recent;
                    server.pid = 0;
                    server
                })
                .collect::<Vec<_>>();

            output.append(&mut stopped_recents);
        }

        output.sort_by(|left, right| {
            match (
                left.status == ServerStatus::Active,
                right.status == ServerStatus::Active,
            ) {
                (true, false) => std::cmp::Ordering::Less,
                (false, true) => std::cmp::Ordering::Greater,
                _ => left
                    .port
                    .cmp(&right.port)
                    .then_with(|| left.id.cmp(&right.id)),
            }
        });
        output.dedup_by(|left, right| server_identity_key(left) == server_identity_key(right));

        for server in &mut output {
            backfill_start_command(server);
            server.group = infer_server_group(server, config.show_automatic_groups);
        }

        self.update_group_stats(&output, &previous_active_keys, &now_text);

        self.recent_servers = output.iter().cloned().take(MAX_RECENT_SERVERS).collect();

        output
    }

    pub fn remove(&mut self, target: &str) -> usize {
        let before_count = self.recent_servers.len() + self.pinned_servers.len();
        self.recent_servers
            .retain(|server| !server_matches_target(server, target));
        self.pinned_servers
            .retain(|server| !server_matches_target(server, target));
        before_count - self.recent_servers.len() - self.pinned_servers.len()
    }

    pub fn hide_server(&mut self, target: &str) -> bool {
        let matching_keys = self
            .recent_servers
            .iter()
            .chain(self.pinned_servers.iter())
            .filter(|server| server_matches_target(server, target))
            .map(server_identity_key)
            .collect::<HashSet<_>>();

        let mut changed = false;
        for key in matching_keys {
            changed = self.hidden_servers.insert(key) || changed;
        }
        changed
    }

    pub fn unhide_server(&mut self, target: &str) -> bool {
        self.hidden_servers.remove(target)
            || self
                .recent_servers
                .iter()
                .chain(self.pinned_servers.iter())
                .filter(|server| server_matches_target(server, target))
                .map(server_identity_key)
                .any(|key| self.hidden_servers.remove(&key))
    }

    pub fn hide_group(&mut self, target: &str) -> bool {
        self.hidden_groups.insert(target.to_string())
    }

    pub fn unhide_group(&mut self, target: &str) -> bool {
        self.hidden_groups.remove(target)
    }

    pub fn visible_servers(&self, servers: Vec<LocalServer>, config: &Config) -> Vec<LocalServer> {
        servers
            .into_iter()
            .filter(|server| !self.hidden_servers.contains(&server_identity_key(server)))
            .filter(|server| {
                server
                    .group
                    .as_ref()
                    .is_none_or(|group| !self.hidden_groups.contains(&group.id))
            })
            .filter(|server| {
                config.show_app_services
                    || server
                        .group
                        .as_ref()
                        .is_none_or(|group| group.kind != "Application Service")
            })
            .collect()
    }

    pub fn set_pinned(&mut self, target: &str, pinned: bool) -> bool {
        let mut changed = false;

        for server in &mut self.recent_servers {
            if server_matches_target(server, target) {
                backfill_start_command(server);
                server.pinned = pinned;
                changed = true;
            }
        }

        if pinned {
            let existing_keys = self
                .pinned_servers
                .iter()
                .map(server_identity_key)
                .collect::<HashSet<_>>();

            for server in &self.recent_servers {
                if server_matches_target(server, target)
                    && !existing_keys.contains(&server_identity_key(server))
                {
                    self.pinned_servers.push(server.clone());
                    changed = true;
                }
            }
        } else {
            let before_count = self.pinned_servers.len();
            self.pinned_servers
                .retain(|server| !server_matches_target(server, target));
            changed = changed || before_count != self.pinned_servers.len();
        }

        changed
    }

    fn update_group_stats(
        &mut self,
        servers: &[LocalServer],
        previous_active_keys: &HashSet<String>,
        now: &str,
    ) {
        for server in servers {
            if server.status != ServerStatus::Active {
                continue;
            }

            let Some(group) = &server.group else {
                continue;
            };

            let entry = self
                .group_stats
                .entry(group.id.clone())
                .or_insert_with(|| GroupStats {
                    id: group.id.clone(),
                    name: group.name.clone(),
                    kind: group.kind.clone(),
                    role: group.role.clone(),
                    source: group.source.clone(),
                    color: group.color.clone(),
                    icon: group.icon.clone(),
                    first_seen_at: now.to_string(),
                    last_seen_at: now.to_string(),
                    active_count: 0,
                });

            entry.name = group.name.clone();
            entry.kind = group.kind.clone();
            entry.role = group.role.clone();
            entry.source = group.source.clone();
            entry.color = group.color.clone();
            entry.icon = group.icon.clone();
            entry.last_seen_at = now.to_string();

            if entry.active_count == 0
                || !previous_active_keys.contains(&server_identity_key(server))
            {
                entry.active_count += 1;
            }
        }
    }
}

fn backfill_start_command(server: &mut LocalServer) {
    if server.start_command.is_none() && !server.command.trim().is_empty() {
        server.start_command = Some(server.command.clone());
    }
}

fn backfill_unknown_active_locations(
    active_servers: &mut [LocalServer],
    previous_servers: &[LocalServer],
) {
    for active in active_servers {
        if active.working_directory.is_some() {
            continue;
        }

        let matches = previous_servers
            .iter()
            .filter(|previous| previous.port == active.port && previous.working_directory.is_some())
            .collect::<Vec<_>>();

        let [previous] = matches.as_slice() else {
            continue;
        };

        active.id = previous.id.clone();
        active.working_directory = previous.working_directory.clone();
        active.display_directory = previous.display_directory.clone();
        active.icon = active.icon.clone().or_else(|| previous.icon.clone());
    }
}

pub fn reset_state() -> Result<(), StateError> {
    remove_file_if_exists(state_path()).map_err(|source| StateError::Write {
        path: state_path(),
        source,
    })
}

fn remove_file_if_exists(path: PathBuf) -> io::Result<()> {
    match fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(source) if source.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(source) => Err(source),
    }
}

fn server_identity_key(server: &LocalServer) -> String {
    format!(
        "{}:{}",
        server.port,
        server.working_directory.as_deref().unwrap_or("unknown")
    )
}

fn server_matches_target(server: &LocalServer, target: &str) -> bool {
    target.parse::<u16>().ok() == Some(server.port)
        || server.id == target
        || server_identity_key(server) == target
}

fn ensure_parent_directory(path: &std::path::Path) -> Result<(), StateError> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|source| StateError::CreateDirectory {
            path: parent.to_path_buf(),
            source,
        })?;
    }

    Ok(())
}

fn temporary_state_path(path: &std::path::Path) -> PathBuf {
    let nonce = OffsetDateTime::now_utc().unix_timestamp_nanos();
    let process_id = std::process::id();
    path.with_extension(format!("json.{process_id}.{nonce}.tmp"))
}

#[derive(Debug, thiserror::Error)]
pub enum StateError {
    #[error("failed to read state file {path}: {source}")]
    Read { path: PathBuf, source: io::Error },
    #[error("failed to parse state file: {0}")]
    Parse(serde_json::Error),
    #[error("failed to create state directory {path}: {source}")]
    CreateDirectory { path: PathBuf, source: io::Error },
    #[error("failed to write state file {path}: {source}")]
    Write { path: PathBuf, source: io::Error },
    #[error("failed to replace state file {from} -> {to}: {source}")]
    Rename {
        from: PathBuf,
        to: PathBuf,
        source: io::Error,
    },
}

fn state_path() -> PathBuf {
    if cfg!(target_os = "windows") {
        if let Some(local_app_data) = std::env::var_os("LOCALAPPDATA") {
            return PathBuf::from(local_app_data)
                .join("Porchlight")
                .join("state.json");
        }
    }

    if let Some(state_home) = std::env::var_os("XDG_STATE_HOME") {
        return PathBuf::from(state_home)
            .join("porchlight")
            .join("state.json");
    }

    let home = std::env::var_os("HOME").unwrap_or_else(|| ".".into());
    PathBuf::from(home)
        .join(".local")
        .join("state")
        .join("porchlight")
        .join("state.json")
}

fn recent_is_fresh(server: &LocalServer, cutoff: OffsetDateTime) -> bool {
    server
        .last_seen_at
        .as_deref()
        .and_then(parse_timestamp)
        .map(|last_seen_at| last_seen_at >= cutoff)
        .unwrap_or(false)
}

fn format_timestamp(timestamp: OffsetDateTime) -> String {
    timestamp
        .format(&time::format_description::well_known::Rfc3339)
        .expect("timestamp formats")
}

fn parse_timestamp(timestamp: &str) -> Option<OffsetDateTime> {
    OffsetDateTime::parse(timestamp, &time::format_description::well_known::Rfc3339).ok()
}

#[cfg(test)]
mod tests {
    use super::{AppState, MAX_RECENT_SERVERS};
    use crate::classification::ServerGroupMatch;
    use crate::config::Config;
    use crate::model::{LocalServer, ServerStatus};
    use std::collections::{HashMap, HashSet};

    #[test]
    fn merges_active_servers_over_matching_recents() {
        let mut state = AppState {
            recent_servers: vec![server("one", 8000, "/tmp/one", ServerStatus::Recent)],
            pinned_servers: vec![],
            group_stats: HashMap::new(),
            hidden_servers: HashSet::new(),
            hidden_groups: HashSet::new(),
        };

        let servers = state.merge_servers(
            vec![server("one-new-id", 8000, "/tmp/one", ServerStatus::Active)],
            &Config::default(),
        );

        assert_eq!(servers.len(), 1);
        assert_eq!(servers[0].id, "one-new-id");
        assert_eq!(servers[0].status, ServerStatus::Active);
        assert_eq!(state.recent_servers.len(), 1);
    }

    #[test]
    fn keeps_distinct_recent_servers_once() {
        let mut state = AppState {
            recent_servers: vec![fresh_recent("old", 3000, "/tmp/old")],
            pinned_servers: vec![],
            group_stats: HashMap::new(),
            hidden_servers: HashSet::new(),
            hidden_groups: HashSet::new(),
        };

        let servers = state.merge_servers(
            vec![server("new", 8000, "/tmp/new", ServerStatus::Active)],
            &Config::default(),
        );

        assert_eq!(
            servers
                .iter()
                .map(|server| server.id.as_str())
                .collect::<Vec<_>>(),
            vec!["new", "old"]
        );
        assert_eq!(servers[1].status, ServerStatus::Recent);
    }

    #[test]
    fn caps_recent_state_size() {
        let mut state = AppState::default();
        let active_servers = (0..(MAX_RECENT_SERVERS + 5))
            .map(|index| {
                server(
                    &format!("server-{index}"),
                    index as u16,
                    &format!("/tmp/server-{index}"),
                    ServerStatus::Active,
                )
            })
            .collect();

        state.merge_servers(active_servers, &Config::default());

        assert_eq!(state.recent_servers.len(), MAX_RECENT_SERVERS);
    }

    #[test]
    fn removes_servers_by_identity() {
        let mut state = AppState {
            recent_servers: vec![
                fresh_recent("one", 8000, "/tmp/one"),
                fresh_recent("two", 9000, "/tmp/two"),
            ],
            pinned_servers: vec![],
            group_stats: HashMap::new(),
            hidden_servers: HashSet::new(),
            hidden_groups: HashSet::new(),
        };

        let removed = state.remove("8000:/tmp/one");

        assert_eq!(removed, 1);
        assert_eq!(state.recent_servers.len(), 1);
        assert_eq!(state.recent_servers[0].id, "two");
    }

    #[test]
    fn pins_and_unpins_servers_by_identity() {
        let mut state = AppState {
            recent_servers: vec![fresh_recent("one", 8000, "/tmp/one")],
            pinned_servers: vec![],
            group_stats: HashMap::new(),
            hidden_servers: HashSet::new(),
            hidden_groups: HashSet::new(),
        };

        assert!(state.set_pinned("8000:/tmp/one", true));
        assert!(state.recent_servers[0].pinned);
        assert_eq!(state.pinned_servers.len(), 1);

        assert!(state.set_pinned("8000:/tmp/one", false));
        assert!(!state.recent_servers[0].pinned);
        assert!(state.pinned_servers.is_empty());
    }

    #[test]
    fn collapses_active_servers_for_the_same_port_and_directory() {
        let mut state = AppState::default();

        let servers = state.merge_servers(
            vec![
                server("first", 8000, "/tmp/same", ServerStatus::Active),
                server("second", 8000, "/tmp/same", ServerStatus::Active),
            ],
            &Config::default(),
        );

        assert_eq!(servers.len(), 1);
        assert_eq!(state.recent_servers.len(), 1);
    }

    #[test]
    fn keeps_scanned_start_command_for_active_server() {
        let mut state = AppState {
            recent_servers: vec![fresh_recent("server", 8000, "/tmp/app")],
            pinned_servers: vec![],
            group_stats: HashMap::new(),
            hidden_servers: HashSet::new(),
            hidden_groups: HashSet::new(),
        };

        let mut active = server("server", 8000, "/tmp/app", ServerStatus::Active);
        active.start_command = Some("npm run dev".into());

        let servers = state.merge_servers(vec![active], &Config::default());

        assert_eq!(servers[0].start_command.as_deref(), Some("npm run dev"));
        assert_eq!(
            state.recent_servers[0].start_command.as_deref(),
            Some("npm run dev")
        );
    }

    #[test]
    fn backfills_unknown_active_location_from_previous_server_on_same_port() {
        let mut state = AppState {
            recent_servers: vec![fresh_recent("server", 8000, "/tmp/app")],
            pinned_servers: vec![],
            group_stats: HashMap::new(),
            hidden_servers: HashSet::new(),
            hidden_groups: HashSet::new(),
        };

        let mut active = server("8000:unknown", 8000, "/tmp/app", ServerStatus::Active);
        active.id = "8000:unknown".into();
        active.working_directory = None;
        active.display_directory = None;

        let servers = state.merge_servers(vec![active], &Config::default());

        assert_eq!(servers.len(), 1);
        assert_eq!(servers[0].id, "server");
        assert_eq!(servers[0].working_directory.as_deref(), Some("/tmp/app"));
        assert_eq!(servers[0].status, ServerStatus::Active);
    }

    #[test]
    fn backfills_start_command_for_existing_recent_server() {
        let mut state = AppState {
            recent_servers: vec![fresh_recent("server", 8000, "/tmp/app")],
            pinned_servers: vec![],
            group_stats: HashMap::new(),
            hidden_servers: HashSet::new(),
            hidden_groups: HashSet::new(),
        };

        let servers = state.merge_servers(vec![], &Config::default());

        assert_eq!(
            servers[0].start_command.as_deref(),
            Some("python manage.py runserver")
        );
        assert_eq!(
            state.recent_servers[0].start_command.as_deref(),
            Some("python manage.py runserver")
        );
    }

    #[test]
    fn recomputes_stale_recent_groups() {
        let mut recent = fresh_recent("server", 8000, "/tmp/app");
        recent.group = Some(ServerGroupMatch {
            id: "deleted-group".into(),
            name: "Deleted Group".into(),
            kind: "Django".into(),
            role: "Web App".into(),
            color: Some("#7C5CFF".into()),
            icon: None,
            confidence: 1.0,
            source: "manual group".into(),
        });
        let mut state = AppState {
            recent_servers: vec![recent],
            pinned_servers: vec![],
            group_stats: HashMap::new(),
            hidden_servers: HashSet::new(),
            hidden_groups: HashSet::new(),
        };
        let config = Config {
            show_automatic_groups: false,
            ..Config::default()
        };

        let servers = state.merge_servers(vec![], &config);

        assert_eq!(servers.len(), 1);
        assert_eq!(servers[0].group, None);
        assert_eq!(state.recent_servers[0].group, None);
    }

    #[test]
    fn counts_group_activation_occurrences_without_counting_refreshes() {
        let root = std::env::temp_dir().join(format!(
            "porchlight-group-stats-test-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&root).unwrap();
        std::fs::write(root.join("README.md"), "# Stats App\n").unwrap();

        let mut state = AppState::default();
        let active = server("server", 8000, root.to_str().unwrap(), ServerStatus::Active);

        state.merge_servers(vec![active.clone()], &Config::default());
        state.merge_servers(vec![active.clone()], &Config::default());
        state.merge_servers(vec![], &Config::default());
        state.merge_servers(vec![active], &Config::default());

        let stats = state.group_stats.get("stats-app").unwrap();
        assert_eq!(stats.active_count, 2);
        assert_eq!(stats.name, "Stats App");
        assert_eq!(stats.kind, "Django");

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn repairs_zero_group_activation_count_for_active_servers() {
        let root = std::env::temp_dir().join(format!(
            "porchlight-group-stats-repair-test-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&root).unwrap();
        std::fs::write(root.join("README.md"), "# Repaired Stats App\n").unwrap();

        let mut state = AppState::default();
        let active = server("server", 8000, root.to_str().unwrap(), ServerStatus::Active);

        state.merge_servers(vec![active.clone()], &Config::default());
        state
            .group_stats
            .get_mut("repaired-stats-app")
            .unwrap()
            .active_count = 0;
        state.merge_servers(vec![active.clone()], &Config::default());
        state.merge_servers(vec![active], &Config::default());

        let stats = state.group_stats.get("repaired-stats-app").unwrap();
        assert_eq!(stats.active_count, 1);

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn filters_hidden_servers_and_groups() {
        let mut visible = server("visible", 8000, "/tmp/visible", ServerStatus::Active);
        visible.group = Some(ServerGroupMatch {
            id: "visible-group".into(),
            name: "Visible Group".into(),
            kind: "Django".into(),
            role: "Backend".into(),
            color: None,
            icon: None,
            confidence: 1.0,
            source: "manual group".into(),
        });
        let mut hidden_by_group = server("grouped", 8001, "/tmp/grouped", ServerStatus::Active);
        hidden_by_group.group = Some(ServerGroupMatch {
            id: "hidden-group".into(),
            name: "Hidden Group".into(),
            kind: "Django".into(),
            role: "Backend".into(),
            color: None,
            icon: None,
            confidence: 1.0,
            source: "manual group".into(),
        });
        let hidden_by_identity = server("hidden", 8002, "/tmp/hidden", ServerStatus::Active);

        let mut state = AppState::default();
        state.hide_group("hidden-group");
        state.hidden_servers.insert("8002:/tmp/hidden".into());

        let servers = state.visible_servers(
            vec![visible.clone(), hidden_by_group, hidden_by_identity],
            &Config::default(),
        );

        assert_eq!(servers, vec![visible]);
    }

    #[test]
    fn filters_application_services_when_disabled() {
        let mut dev = server("dev", 8000, "/tmp/dev", ServerStatus::Active);
        dev.group = Some(ServerGroupMatch {
            id: "dev".into(),
            name: "Dev".into(),
            kind: "Django".into(),
            role: "Backend".into(),
            color: None,
            icon: None,
            confidence: 1.0,
            source: "README".into(),
        });
        let mut app_service = server("app", 9877, "/", ServerStatus::Active);
        app_service.group = Some(ServerGroupMatch {
            id: "ableton-live-12-suite".into(),
            name: "Ableton Live 12 Suite".into(),
            kind: "Application Service".into(),
            role: "Background Service".into(),
            color: None,
            icon: None,
            confidence: 0.78,
            source: "application bundle path".into(),
        });
        let state = AppState::default();
        let config = Config {
            show_app_services: false,
            ..Config::default()
        };

        let servers = state.visible_servers(vec![dev.clone(), app_service], &config);

        assert_eq!(servers, vec![dev]);
    }

    fn fresh_recent(id: &str, port: u16, working_directory: &str) -> LocalServer {
        let mut server = server(id, port, working_directory, ServerStatus::Recent);
        server.last_seen_at = Some("2999-01-01T00:00:00Z".into());
        server
    }

    fn server(id: &str, port: u16, working_directory: &str, status: ServerStatus) -> LocalServer {
        LocalServer {
            id: id.into(),
            port,
            pid: 123,
            status,
            process_name: "python".into(),
            server_type: "Django".into(),
            icon: None,
            group: None,
            command: "python manage.py runserver".into(),
            working_directory: Some(working_directory.into()),
            display_directory: Some(working_directory.into()),
            url: format!("http://localhost:{port}"),
            pinned: false,
            last_seen_at: None,
            start_command: None,
        }
    }
}
