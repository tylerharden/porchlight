use serde::{Deserialize, Serialize};
use std::sync::OnceLock;

const SERVER_TYPES_JSON: &str = include_str!("server_types.json");

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ServerList {
    pub servers: Vec<LocalServer>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct LocalServer {
    pub id: String,
    pub port: u16,
    pub pid: u32,
    pub status: ServerStatus,
    pub process_name: String,
    pub server_type: String,
    pub command: String,
    pub working_directory: Option<String>,
    pub display_directory: Option<String>,
    pub url: String,
    pub pinned: bool,
    pub last_seen_at: Option<String>,
    pub start_command: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
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
    use super::infer_server_type;

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
}
