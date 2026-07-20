use crate::classification::ServerGroupMatch;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::sync::OnceLock;

const SERVER_TYPES_JSON: &str = include_str!("server_types.json");

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct ServerList {
    pub servers: Vec<LocalServer>,
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct LocalServer {
    pub id: String,
    pub port: u16,
    pub pid: u32,
    pub status: ServerStatus,
    pub process_name: String,
    pub server_type: String,
    #[serde(default)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
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

pub fn infer_server_type_for_project(
    process_name: &str,
    command: &str,
    working_directory: Option<&str>,
) -> String {
    if is_fastapi_project(command, working_directory) {
        return "FastAPI".to_string();
    }

    let haystack = format!("{process_name} {command}").to_lowercase();

    server_type_rules()
        .iter()
        .find(|rule| rule.matches(&haystack))
        .map(|rule| rule.label.clone())
        .unwrap_or_else(|| fallback_server_type(process_name))
}

fn is_fastapi_project(command: &str, working_directory: Option<&str>) -> bool {
    if !command.to_lowercase().contains("uvicorn") {
        return false;
    }

    let Some(root) = working_directory.map(PathBuf::from) else {
        return false;
    };

    fastapi_module_path(command)
        .map(|module_path| root.join(module_path))
        .filter(|path| file_uses_fastapi(path))
        .is_some()
}

fn fastapi_module_path(command: &str) -> Option<PathBuf> {
    command
        .split_whitespace()
        .find(|part| {
            part.contains(':')
                && !part.starts_with('-')
                && part
                    .chars()
                    .all(|character| character.is_ascii_alphanumeric() || ".:_".contains(character))
        })
        .and_then(|part| part.split_once(':').map(|(module, _)| module))
        .filter(|module| !module.is_empty())
        .map(|module| PathBuf::from(module.replace('.', "/")).with_extension("py"))
}

fn file_uses_fastapi(path: &Path) -> bool {
    let Ok(contents) = std::fs::read_to_string(path) else {
        return false;
    };

    contents.contains("from fastapi import")
        || contents.contains("import fastapi")
        || contents.contains("FastAPI(")
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
    use super::infer_server_type_for_project;

    #[test]
    fn infers_common_server_types() {
        assert_eq!(
            infer_server_type_for_project("Python", "python manage.py runserver 8000", None),
            "Django"
        );
        assert_eq!(
            infer_server_type_for_project("node", "npm exec vite --host", None),
            "Vite"
        );
        assert_eq!(
            infer_server_type_for_project("node", "next dev", None),
            "Next.js"
        );
        assert_eq!(
            infer_server_type_for_project("ruby", "rails server", None),
            "Rails"
        );
        assert_eq!(
            infer_server_type_for_project("python", "uvicorn app:app", None),
            "Uvicorn"
        );
        assert_eq!(
            infer_server_type_for_project("node", "live-server --port=5501", None),
            "Live Server"
        );
    }

    #[test]
    fn prefers_fastapi_over_uvicorn_when_project_module_uses_fastapi() {
        let root =
            std::env::temp_dir().join(format!("porchlight-fastapi-test-{}", std::process::id()));
        let app_dir = root.join("app");
        std::fs::create_dir_all(&app_dir).unwrap();
        std::fs::write(
            app_dir.join("main.py"),
            "from fastapi import FastAPI\n\napp = FastAPI()\n",
        )
        .unwrap();

        assert_eq!(
            infer_server_type_for_project(
                "python",
                "uvicorn app.main:app --reload --port 8000",
                Some(root.to_str().unwrap())
            ),
            "FastAPI"
        );

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn falls_back_to_process_name() {
        assert_eq!(
            infer_server_type_for_project("postgres", "postgres", None),
            "postgres"
        );
        assert_eq!(infer_server_type_for_project("", "", None), "Unknown");
    }
}
