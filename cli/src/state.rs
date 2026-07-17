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

        let temporary_path = path.with_extension("json.tmp");
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
        active_servers: Vec<LocalServer>,
        config: &Config,
    ) -> Vec<LocalServer> {
        let now = OffsetDateTime::now_utc();
        let now_text = format_timestamp(now);
        let active_keys = active_servers
            .iter()
            .map(server_identity_key)
            .collect::<HashSet<_>>();

        let previous_recent_servers = std::mem::take(&mut self.recent_servers);
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
                server.start_command = previous
                    .and_then(|server| server.start_command.clone())
                    .or(server.start_command);
                server
            })
            .collect::<Vec<_>>();

        if config.show_recents {
            let cutoff = now - Duration::minutes(config.recent_ttl_minutes as i64);
            let mut stopped_recents = recent_by_key
                .into_values()
                .filter(|server| !active_keys.contains(&server_identity_key(server)))
                .filter(|server| recent_is_fresh(server, cutoff) || server.pinned)
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
    use crate::config::Config;
    use crate::model::{LocalServer, ServerStatus};

    #[test]
    fn merges_active_servers_over_matching_recents() {
        let mut state = AppState {
            recent_servers: vec![server("one", 8000, "/tmp/one", ServerStatus::Recent)],
            pinned_servers: vec![],
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
        };

        let removed = state.remove("8000:/tmp/one");

        assert_eq!(removed, 1);
        assert_eq!(state.recent_servers.len(), 1);
        assert_eq!(state.recent_servers[0].id, "two");
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
