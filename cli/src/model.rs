use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::OnceLock;

const SERVER_TYPES_JSON: &str = include_str!("server_types.json");

#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
pub struct ServerList {
    pub servers: Vec<LocalServer>,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
pub struct LocalServer {
    pub id: String,
    pub port: u16,
    pub pid: u32,
    pub status: ServerStatus,
    pub process_name: String,
    pub server_type: String,
    #[serde(default)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub group: Option<ServerGroupMatch>,
    pub command: String,
    pub working_directory: Option<String>,
    pub display_directory: Option<String>,
    pub url: String,
    pub pinned: bool,
    pub last_seen_at: Option<String>,
    pub start_command: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
pub struct ServerGroupMatch {
    pub id: String,
    pub name: String,
    pub color: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
pub struct ServerGroups {
    #[serde(default)]
    pub groups: Vec<ServerGroup>,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
pub struct ServerGroup {
    pub id: String,
    pub name: String,
    pub color: String,
    #[serde(default)]
    pub command_contains: Vec<String>,
    #[serde(default)]
    pub working_directories: Vec<String>,
    pub priority: i32,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
#[allow(dead_code)]
pub enum ServerStatus {
    Active,
    Recent,
    Stopped,
    Unknown,
}

#[derive(Debug, Deserialize)]
struct ServerTypeRule {
    label: String,
    match_any: Vec<Vec<String>>,
}

pub fn infer_server_type(process_name: &str, command: &str) -> String {
    let haystack = format!("{process_name} {command}").to_lowercase();

    server_type_rules()
        .iter()
        .find(|rule| rule.matches(&haystack))
        .map(|rule| rule.label.clone())
        .unwrap_or_else(|| fallback_server_type(process_name))
}

pub fn infer_server_group(command: &str, working_directory: Option<&str>) -> Option<ServerGroupMatch> {
    let command = command.to_lowercase();
    let working_directory = working_directory.unwrap_or_default().to_lowercase();

    let mut groups = load_server_groups().groups;
    groups.sort_by(|left, right| right.priority.cmp(&left.priority));

    groups
        .into_iter()
        .find(|group| group.matches(&command, &working_directory))
        .map(|group| ServerGroupMatch {
            id: group.id,
            name: group.name,
            color: group.color,
        })
}

fn load_server_groups() -> ServerGroups {
    let path = server_groups_path();
    let Ok(contents) = std::fs::read_to_string(path) else {
        return ServerGroups { groups: vec![] };
    };

    serde_json::from_str(&contents).unwrap_or(ServerGroups { groups: vec![] })
}

fn server_groups_path() -> PathBuf {
    let home = std::env::var_os("HOME").unwrap_or_else(|| ".".into());
    PathBuf::from(home)
        .join(".config")
        .join("porchlight")
        .join("groups.json")
}

fn server_type_rules() -> &'static [ServerTypeRule] {
    static RULES: OnceLock<Vec<ServerTypeRule>> = OnceLock::new();

    RULES.get_or_init(|| {
        serde_json::from_str(SERVER_TYPES_JSON).expect("server type rules JSON is valid")
    })
}

impl ServerTypeRule {
    fn matches(&self, haystack: &str) -> bool {
        self.match_any.iter().any(|terms| {
            terms
                .iter()
                .all(|term| haystack.contains(&term.to_lowercase()))
        })
    }
}

impl ServerGroup {
    fn matches(&self, command: &str, working_directory: &str) -> bool {
        let has_command_rules = self.command_contains.iter().any(|value| !value.trim().is_empty());
        let has_directory_rules = self
            .working_directories
            .iter()
            .any(|value| !value.trim().is_empty());

        if !has_command_rules && !has_directory_rules {
            return false;
        }

        let command_matches = !has_command_rules
            || self
                .command_contains
                .iter()
                .filter(|value| !value.trim().is_empty())
                .any(|value| command.contains(&value.to_lowercase()));
        let directory_matches = !has_directory_rules
            || self
                .working_directories
                .iter()
                .filter(|value| !value.trim().is_empty())
                .any(|value| working_directory.contains(&value.to_lowercase()));

        command_matches && directory_matches
    }
}

fn fallback_server_type(process_name: &str) -> String {
    let process_name = process_name.trim();

    if process_name.is_empty() {
        "Unknown".to_string()
    } else {
        process_name.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::{infer_server_type, ServerGroup};

    #[test]
    fn infers_common_server_types() {
        assert_eq!(
            infer_server_type("Python", "python manage.py runserver 8000"),
            "Django"
        );
        assert_eq!(infer_server_type("node", "npm exec vite --host"), "Vite");
        assert_eq!(infer_server_type("node", "next dev"), "Next.js");
        assert_eq!(infer_server_type("ruby", "rails server"), "Rails");
        assert_eq!(infer_server_type("python", "uvicorn app:app"), "Uvicorn");
        assert_eq!(
            infer_server_type("node", "live-server --port=5501"),
            "Live Server"
        );
    }

    #[test]
    fn falls_back_to_process_name() {
        assert_eq!(infer_server_type("postgres", "postgres"), "postgres");
        assert_eq!(infer_server_type("", ""), "Unknown");
    }

    #[test]
    fn group_matches_non_empty_rule_categories() {
        let group = ServerGroup {
            id: "alexandria".into(),
            name: "Alexandria".into(),
            color: "#34C759".into(),
            command_contains: vec!["manage.py".into()],
            working_directories: vec!["/developer/alexandria".into()],
            priority: 100,
        };

        assert!(group.matches(
            "uv run python manage.py runserver",
            "/users/tyler/developer/alexandria"
        ));
        assert!(!group.matches(
            "uv run python manage.py runserver",
            "/users/tyler/developer/other"
        ));
    }
}
