use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
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
    #[serde(default)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
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
    #[serde(default)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
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
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
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

pub fn infer_server_group(
    command: &str,
    working_directory: Option<&str>,
) -> Option<ServerGroupMatch> {
    let command = command.to_lowercase();
    let original_working_directory = working_directory.unwrap_or_default();
    let working_directory = original_working_directory.to_lowercase();

    let mut groups = load_server_groups().groups;
    groups.sort_by(|left, right| right.priority.cmp(&left.priority));

    groups
        .into_iter()
        .find(|group| group.matches(&command, &working_directory))
        .map(|group| ServerGroupMatch {
            id: group.id,
            name: group.name,
            color: group.color,
            icon: group
                .icon
                .filter(|icon| !icon.trim().is_empty())
                .or_else(|| discover_project_icon(original_working_directory)),
        })
}

pub fn discover_project_icon(working_directory: &str) -> Option<String> {
    if working_directory.is_empty() {
        return None;
    }

    let root = PathBuf::from(working_directory);
    [
        "public/favicon.ico",
        "public/favicon.png",
        "public/apple-touch-icon.png",
        "app/favicon.ico",
        "app/static/favicon.ico",
        "app/static/favicon.png",
        "app/static/favicon-32x32.png",
        "app/static/favicon-16x16.png",
        "src/app/favicon.ico",
        "static/favicon.ico",
        "static/favicon.png",
        "assets/favicon.ico",
        "assets/favicon.png",
        "favicon.ico",
        "favicon.png",
    ]
    .iter()
    .map(|candidate| root.join(candidate))
    .find(|path| path.is_file())
    .map(|path| path.to_string_lossy().to_string())
}

pub fn load_server_groups() -> ServerGroups {
    let path = server_groups_path();
    let Ok(contents) = std::fs::read_to_string(path) else {
        return ServerGroups { groups: vec![] };
    };

    serde_json::from_str(&contents).unwrap_or(ServerGroups { groups: vec![] })
}

pub fn save_server_groups(groups: &ServerGroups) -> std::io::Result<()> {
    let path = server_groups_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    let contents = serde_json::to_string_pretty(groups).expect("server groups serialize");
    std::fs::write(path, format!("{contents}\n"))
}

pub fn server_groups_path() -> PathBuf {
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
        let has_command_rules = self
            .command_contains
            .iter()
            .any(|value| !value.trim().is_empty());
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
    use super::{discover_project_icon, infer_server_type_for_project, ServerGroup};

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

    #[test]
    fn group_matches_non_empty_rule_categories() {
        let group = ServerGroup {
            id: "alexandria".into(),
            name: "Alexandria".into(),
            color: "#34C759".into(),
            icon: None,
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

    #[test]
    fn discovers_common_project_icon_paths() {
        let root =
            std::env::temp_dir().join(format!("porchlight-icon-test-{}", std::process::id()));
        let public = root.join("public");
        std::fs::create_dir_all(&public).unwrap();
        let icon = public.join("favicon.ico");
        std::fs::write(&icon, []).unwrap();

        assert_eq!(
            discover_project_icon(root.to_str().unwrap()).as_deref(),
            Some(icon.to_str().unwrap())
        );

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn discovers_nested_app_static_icon_paths() {
        let root = std::env::temp_dir().join(format!(
            "porchlight-nested-icon-test-{}",
            std::process::id()
        ));
        let static_dir = root.join("app/static");
        std::fs::create_dir_all(&static_dir).unwrap();
        let icon = static_dir.join("favicon.ico");
        std::fs::write(&icon, []).unwrap();

        assert_eq!(
            discover_project_icon(root.to_str().unwrap()).as_deref(),
            Some(icon.to_str().unwrap())
        );

        let _ = std::fs::remove_dir_all(root);
    }
}
