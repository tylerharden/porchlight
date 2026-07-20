use crate::model::LocalServer;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

const CLASSIFICATION_RULES_JSON: &str = include_str!("classification_rules.json");

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ServerGroupMatch {
    pub id: String,
    pub name: String,
    pub kind: String,
    pub role: String,
    #[serde(default)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub color: Option<String>,
    #[serde(default)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
    pub confidence: f32,
    pub source: String,
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

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct ClassificationRules {
    #[serde(default)]
    pub rules: Vec<ClassificationRule>,
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct ClassificationRule {
    pub id: String,
    pub name: String,
    pub kind: String,
    pub role: String,
    #[serde(default)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub color: Option<String>,
    #[serde(default)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
    #[serde(default = "default_rule_confidence")]
    pub confidence: f32,
    #[serde(default)]
    pub priority: i32,
    #[serde(default)]
    pub match_any: Vec<Vec<String>>,
}

pub fn auto_group(
    process_name: &str,
    command: &str,
    working_directory: Option<&str>,
    server_type: &str,
    icon: Option<String>,
) -> Option<ServerGroupMatch> {
    let root = working_directory.and_then(project_root);
    if let Some(root) = root.as_deref() {
        if let Some(name) = infer_path_family_name(root) {
            let kind = infer_project_kind(root, command, server_type);
            let source = format!(
                "worktree path + {}",
                category_source(root, command, server_type)
            );

            return Some(ServerGroupMatch {
                id: slugify(&name),
                name,
                role: project_role_for_kind(&kind).to_string(),
                kind,
                color: None,
                icon,
                confidence: infer_confidence(&source),
                source,
            });
        }
    }

    if let Some(group) = rule_group(
        process_name,
        command,
        working_directory,
        server_type,
        icon.clone(),
    ) {
        return Some(group);
    }

    if let Some(group) = app_bundle_group(command, working_directory, server_type, icon.clone()) {
        return Some(group);
    }

    let root = root.or_else(|| project_root(working_directory?))?;
    let kind = infer_project_kind(&root, command, server_type);
    let name = infer_project_name(&root).unwrap_or_else(|| titleize(root.file_name_text()));
    let source = category_source(&root, command, server_type);

    Some(ServerGroupMatch {
        id: slugify(&name),
        name,
        role: project_role_for_kind(&kind).to_string(),
        kind,
        color: None,
        icon,
        confidence: infer_confidence(&source),
        source,
    })
}

fn rule_group(
    process_name: &str,
    command: &str,
    working_directory: Option<&str>,
    server_type: &str,
    discovered_icon: Option<String>,
) -> Option<ServerGroupMatch> {
    let haystack = format!(
        "{} {} {} {}",
        process_name,
        command,
        working_directory.unwrap_or_default(),
        server_type
    )
    .to_lowercase();

    let mut rules = match load_classification_rules() {
        Ok(rules) => rules.rules,
        Err(error) => {
            eprintln!("porchlight: {error}");
            return None;
        }
    };
    rules.sort_by(|left, right| right.priority.cmp(&left.priority));

    rules
        .into_iter()
        .find(|rule| rule.matches(&haystack))
        .map(|rule| ServerGroupMatch {
            id: rule.id,
            name: rule.name,
            kind: rule.kind,
            role: rule.role,
            color: rule.color.map(|color| normalize_color(&color)),
            icon: rule
                .icon
                .filter(|icon| !icon.trim().is_empty())
                .or(discovered_icon),
            confidence: rule.confidence,
            source: "classification rule".to_string(),
        })
}

fn app_bundle_group(
    command: &str,
    working_directory: Option<&str>,
    server_type: &str,
    icon: Option<String>,
) -> Option<ServerGroupMatch> {
    let bundle = find_app_bundle_text(command)
        .or_else(|| working_directory.and_then(find_app_bundle_text))?;
    let (name, id) = app_bundle_identity(&bundle)?;
    let icon = icon.or_else(|| discover_app_bundle_icon(&bundle));

    Some(ServerGroupMatch {
        id,
        name,
        kind: "Application Service".to_string(),
        role: "Background Service".to_string(),
        color: None,
        icon,
        confidence: if server_type == "Unknown" { 0.7 } else { 0.78 },
        source: "application bundle path".to_string(),
    })
}

fn find_app_bundle_text(value: &str) -> Option<String> {
    let end = value.to_lowercase().find(".app")? + ".app".len();
    let prefix = &value[..end];
    let start = prefix.rfind(" /").map(|index| index + 1).unwrap_or(0);
    let bundle = prefix[start..].trim_matches(['\'', '"']).trim().to_string();

    bundle.contains('/').then_some(bundle)
}

fn discover_app_bundle_icon(bundle: &str) -> Option<String> {
    let bundle = PathBuf::from(bundle);
    let resources = bundle.join("Contents").join("Resources");
    if !resources.is_dir() {
        return None;
    }

    let app_stem = bundle
        .file_name()
        .and_then(|name| name.to_str())
        .map(|name| name.trim_end_matches(".app"));
    let preferred_names = [
        app_stem.map(|name| format!("{name}.icns")),
        Some("app.icns".to_string()),
        Some("icon.icns".to_string()),
        Some("cc_app.icns".to_string()),
    ];

    for name in preferred_names.into_iter().flatten() {
        let candidate = resources.join(name);
        if candidate.is_file() {
            return Some(candidate.to_string_lossy().to_string());
        }
    }

    let mut candidates = std::fs::read_dir(resources)
        .ok()?
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| {
            path.extension()
                .and_then(|extension| extension.to_str())
                .is_some_and(|extension| extension.eq_ignore_ascii_case("icns"))
        })
        .filter(|path| {
            path.file_stem()
                .and_then(|stem| stem.to_str())
                .is_none_or(|stem| !stem.eq_ignore_ascii_case("generic"))
        })
        .collect::<Vec<_>>();
    candidates.sort();

    candidates
        .into_iter()
        .next()
        .map(|path| path.to_string_lossy().to_string())
}

fn app_bundle_identity(bundle: &str) -> Option<(String, String)> {
    let components = bundle
        .split('/')
        .filter(|component| !component.is_empty())
        .collect::<Vec<_>>();
    let app_index = components
        .iter()
        .position(|component| component.to_lowercase().ends_with(".app"))?;
    let app_name = components[app_index].trim_end_matches(".app");
    let parent_name = app_index
        .checked_sub(1)
        .and_then(|index| components.get(index));
    let preferred_parent_name = parent_name
        .copied()
        .filter(|parent| should_prefer_parent_app_name(app_name, parent));
    let vendor_name = preferred_parent_name
        .and_then(|_| app_index.checked_sub(2))
        .and_then(|index| components.get(index))
        .copied()
        .filter(|value| !is_generic_path_component(value));

    let base_name = preferred_parent_name.unwrap_or(app_name);
    let name = match vendor_name {
        Some(vendor) if !same_normalized_name(vendor, base_name) => {
            format!("{} {}", titleize(vendor), titleize(base_name))
        }
        _ => titleize(base_name),
    };

    Some((name.clone(), slugify(&name)))
}

fn should_prefer_parent_app_name(app_name: &str, parent_name: &str) -> bool {
    let normalized_app = normalize_name(app_name);
    let normalized_parent = normalize_name(parent_name);

    !normalized_parent.is_empty()
        && !is_generic_path_component(parent_name)
        && (normalized_app.len() <= 4
            || normalized_app.contains("helper")
            || normalized_app.contains("service")
            || normalized_app.contains("library")
            || normalized_app.starts_with("cc"))
}

fn is_generic_path_component(value: &str) -> bool {
    matches!(
        normalize_name(value).as_str(),
        "library"
            | "applications"
            | "application support"
            | "contents"
            | "macos"
            | "resources"
            | "helpers"
            | "frameworks"
    )
}

fn same_normalized_name(left: &str, right: &str) -> bool {
    normalize_name(left) == normalize_name(right)
}

fn normalize_name(value: &str) -> String {
    value
        .trim_end_matches(".app")
        .replace(['-', '_'], " ")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase()
}

pub fn infer_user_group(
    command: &str,
    working_directory: Option<&str>,
    server_type: &str,
) -> Option<ServerGroupMatch> {
    let command = command.to_lowercase();
    let original_working_directory = working_directory.unwrap_or_default();
    let working_directory = original_working_directory.to_lowercase();

    let mut groups = load_server_groups().groups;
    groups.sort_by(|left, right| right.priority.cmp(&left.priority));

    groups
        .into_iter()
        .find(|group| group.matches(&command, &working_directory))
        .map(|group| {
            let icon = group
                .icon
                .filter(|icon| !icon.trim().is_empty())
                .or_else(|| discover_project_icon(original_working_directory));

            manual_group_match(group.id, group.name, group.color, icon, server_type)
        })
}

pub fn infer_server_group(
    server: &LocalServer,
    show_automatic_groups: bool,
) -> Option<ServerGroupMatch> {
    infer_user_group(
        &server.command,
        server.working_directory.as_deref(),
        &server.server_type,
    )
    .or_else(|| {
        if !show_automatic_groups {
            return None;
        }

        auto_group(
            &server.process_name,
            &server.command,
            server.working_directory.as_deref(),
            &server.server_type,
            server.icon.clone(),
        )
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
    if let Ok(contents) = std::fs::read_to_string(path) {
        return serde_json::from_str(&contents).unwrap_or(ServerGroups { groups: vec![] });
    }

    ServerGroups { groups: vec![] }
}

pub fn save_server_groups(groups: &ServerGroups) -> std::io::Result<()> {
    let path = server_groups_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    let contents = serde_json::to_string_pretty(groups).expect("server groups serialize");
    std::fs::write(path, format!("{contents}\n"))
}

pub fn load_classification_rules() -> Result<ClassificationRules, ClassificationError> {
    let mut rules = built_in_classification_rules();
    for user_rule in load_user_classification_rules()? {
        rules.retain(|rule| rule.id != user_rule.id);
        rules.push(user_rule);
    }

    Ok(ClassificationRules { rules })
}

pub fn classification_rules_path() -> PathBuf {
    config_dir().join("classification_rules.json")
}

pub fn server_groups_path() -> PathBuf {
    config_dir().join("groups.json")
}

fn config_dir() -> PathBuf {
    let home = std::env::var_os("HOME").unwrap_or_else(|| ".".into());
    PathBuf::from(home).join(".config").join("porchlight")
}

fn built_in_classification_rules() -> Vec<ClassificationRule> {
    serde_json::from_str::<Vec<ClassificationRule>>(CLASSIFICATION_RULES_JSON)
        .expect("built-in classification rules JSON is valid")
}

fn load_user_classification_rules() -> Result<Vec<ClassificationRule>, ClassificationError> {
    let path = classification_rules_path();
    let Ok(contents) = std::fs::read_to_string(path) else {
        return Ok(vec![]);
    };

    if let Ok(document) = serde_json::from_str::<ClassificationRules>(&contents) {
        return Ok(document.rules);
    }

    serde_json::from_str::<Vec<ClassificationRule>>(&contents).map_err(|source| {
        ClassificationError::InvalidRules {
            path: classification_rules_path().display().to_string(),
            source,
        }
    })
}

#[derive(Debug, thiserror::Error)]
pub enum ClassificationError {
    #[error("failed to parse classification rules file {path}: {source}")]
    InvalidRules {
        path: String,
        source: serde_json::Error,
    },
}

fn default_rule_confidence() -> f32 {
    0.85
}

fn project_root(working_directory: &str) -> Option<PathBuf> {
    let path = PathBuf::from(working_directory);
    if path.exists() {
        Some(path)
    } else {
        None
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

impl ClassificationRule {
    fn matches(&self, haystack: &str) -> bool {
        !self.match_any.is_empty()
            && self.match_any.iter().any(|terms| {
                terms
                    .iter()
                    .filter(|term| !term.trim().is_empty())
                    .all(|term| haystack.contains(&term.to_lowercase()))
            })
    }
}

fn infer_project_kind(root: &Path, command: &str, server_type: &str) -> String {
    if has_file(root, "manage.py") {
        return "Django".to_string();
    }

    if server_type == "FastAPI" {
        return "FastAPI".to_string();
    }

    if has_any_file(
        root,
        &["next.config.js", "next.config.mjs", "next.config.ts"],
    ) {
        return "Next.js".to_string();
    }

    if has_any_file(
        root,
        &["vite.config.js", "vite.config.mjs", "vite.config.ts"],
    ) {
        return "Vite".to_string();
    }

    if has_any_file(root, &["Cargo.toml"]) {
        return "Rust".to_string();
    }

    if has_any_file(root, &["go.mod"]) {
        return "Go".to_string();
    }

    if has_any_file(root, &["Gemfile"]) && command.to_lowercase().contains("rails") {
        return "Rails".to_string();
    }

    if server_type.trim().is_empty() {
        "Unknown".to_string()
    } else {
        server_type.to_string()
    }
}

pub fn manual_group_match(
    id: String,
    name: String,
    color: String,
    icon: Option<String>,
    server_type: &str,
) -> ServerGroupMatch {
    let kind = if server_type.trim().is_empty() {
        "Group".to_string()
    } else {
        server_type.to_string()
    };

    ServerGroupMatch {
        id,
        name,
        role: project_role_for_kind(&kind).to_string(),
        kind,
        color: Some(normalize_color(&color)),
        icon,
        confidence: 1.0,
        source: "manual group".to_string(),
    }
}

fn normalize_color(color: &str) -> String {
    let color = color.trim();
    if color.is_empty() {
        "#7C5CFF".to_string()
    } else {
        color.to_string()
    }
}

pub fn project_role_for_kind(kind: &str) -> &'static str {
    match kind {
        "Django" | "FastAPI" | "Rails" | "Uvicorn" | "Gunicorn" => "Backend",
        "Next.js" | "Nuxt" | "Astro" | "Vite" | "Live Server" => "Frontend",
        _ => "Service",
    }
}

fn infer_project_name(root: &Path) -> Option<String> {
    read_readme_heading(root)
        .or_else(|| read_package_json_name(root))
        .or_else(|| read_pyproject_name(root))
        .or_else(|| read_cargo_name(root))
        .or_else(|| read_go_module_name(root))
        .map(|name| titleize(&name))
}

fn infer_path_family_name(root: &Path) -> Option<String> {
    let parent = root.parent()?.file_name()?.to_str()?;

    for suffix in [
        "-worktrees",
        "_worktrees",
        " worktrees",
        "-worktree",
        "_worktree",
    ] {
        if let Some(project) = parent.strip_suffix(suffix) {
            let project = project.trim_matches(['-', '_', ' ']);
            if !project.is_empty() {
                return Some(titleize(project));
            }
        }
    }

    None
}

fn category_source(root: &Path, command: &str, server_type: &str) -> String {
    let mut sources = Vec::new();

    if has_file(root, "manage.py") {
        sources.push("manage.py");
    }
    if has_any_file(root, &["README.md", "readme.md"]) {
        sources.push("README");
    }
    if has_file(root, "package.json") {
        sources.push("package.json");
    }
    if has_file(root, "pyproject.toml") {
        sources.push("pyproject.toml");
    }
    if has_any_file(
        root,
        &["next.config.js", "next.config.mjs", "next.config.ts"],
    ) {
        sources.push("next.config");
    }
    if has_any_file(
        root,
        &["vite.config.js", "vite.config.mjs", "vite.config.ts"],
    ) {
        sources.push("vite.config");
    }
    if !command.trim().is_empty() {
        sources.push("process command");
    }
    if server_type != "Unknown" {
        sources.push("server type");
    }

    if sources.is_empty() {
        "working directory".to_string()
    } else {
        sources.join(" + ")
    }
}

fn infer_confidence(source: &str) -> f32 {
    let mut confidence = 0.55;

    for marker in [
        "manage.py",
        "next.config",
        "vite.config",
        "package.json",
        "pyproject.toml",
        "README",
        "process command",
    ] {
        if source.contains(marker) {
            confidence += 0.06;
        }
    }

    f32::min(confidence, 0.95)
}

fn read_readme_heading(root: &Path) -> Option<String> {
    ["README.md", "readme.md"]
        .iter()
        .find_map(|file| std::fs::read_to_string(root.join(file)).ok())
        .and_then(|contents| {
            contents.lines().find_map(|line| {
                line.trim()
                    .strip_prefix("# ")
                    .map(str::trim)
                    .filter(|value| !value.is_empty())
                    .map(ToString::to_string)
            })
        })
}

fn read_package_json_name(root: &Path) -> Option<String> {
    let contents = std::fs::read_to_string(root.join("package.json")).ok()?;
    let value = serde_json::from_str::<serde_json::Value>(&contents).ok()?;
    value.get("name")?.as_str().map(ToString::to_string)
}

fn read_pyproject_name(root: &Path) -> Option<String> {
    let contents = std::fs::read_to_string(root.join("pyproject.toml")).ok()?;
    extract_toml_string(&contents, "name")
}

fn read_cargo_name(root: &Path) -> Option<String> {
    let contents = std::fs::read_to_string(root.join("Cargo.toml")).ok()?;
    extract_toml_string(&contents, "name")
}

fn read_go_module_name(root: &Path) -> Option<String> {
    let contents = std::fs::read_to_string(root.join("go.mod")).ok()?;
    contents.lines().find_map(|line| {
        line.trim()
            .strip_prefix("module ")
            .and_then(|module| module.rsplit('/').next())
            .filter(|value| !value.is_empty())
            .map(ToString::to_string)
    })
}

fn extract_toml_string(contents: &str, key: &str) -> Option<String> {
    contents.lines().find_map(|line| {
        let line = line.trim();
        let (left, right) = line.split_once('=')?;
        if left.trim() != key {
            return None;
        }

        Some(right.trim().trim_matches('"').to_string()).filter(|value| !value.is_empty())
    })
}

fn has_file(root: &Path, relative_path: &str) -> bool {
    root.join(relative_path).is_file()
}

fn has_any_file(root: &Path, relative_paths: &[&str]) -> bool {
    relative_paths.iter().any(|path| has_file(root, path))
}

fn slugify(value: &str) -> String {
    let slug = value
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() {
                character.to_ascii_lowercase()
            } else {
                '-'
            }
        })
        .collect::<String>()
        .split('-')
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join("-");

    if slug.is_empty() {
        "unknown".to_string()
    } else {
        slug
    }
}

fn titleize(value: &str) -> String {
    value
        .trim()
        .trim_start_matches('@')
        .replace(['-', '_'], " ")
        .split('/')
        .next_back()
        .unwrap_or_default()
        .split_whitespace()
        .map(|word| {
            let mut chars = word.chars();
            match chars.next() {
                Some(first) => format!("{}{}", first.to_uppercase(), chars.as_str()),
                None => String::new(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

trait FileNameText {
    fn file_name_text(&self) -> &str;
}

impl FileNameText for Path {
    fn file_name_text(&self) -> &str {
        self.file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("Unknown")
    }
}

#[cfg(test)]
mod tests {
    use super::{auto_group, discover_project_icon, ServerGroup};

    #[test]
    fn auto_groups_django_from_project_markers() {
        let root = std::env::temp_dir().join(format!(
            "porchlight-django-project-test-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&root).unwrap();
        std::fs::write(root.join("manage.py"), "").unwrap();
        std::fs::write(root.join("README.md"), "# Alexandria\n").unwrap();

        let group = auto_group(
            "Python",
            "python manage.py runserver 8000",
            Some(root.to_str().unwrap()),
            "Django",
            None,
        )
        .unwrap();

        assert_eq!(group.id, "alexandria");
        assert_eq!(group.name, "Alexandria");
        assert_eq!(group.kind, "Django");
        assert_eq!(group.role, "Backend");
        assert!(group.source.contains("manage.py"));

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn auto_groups_vite_from_package_metadata() {
        let root = std::env::temp_dir().join(format!(
            "porchlight-vite-project-test-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&root).unwrap();
        std::fs::write(root.join("vite.config.ts"), "").unwrap();
        std::fs::write(root.join("package.json"), r#"{"name":"mdt-web"}"#).unwrap();

        let group = auto_group(
            "node",
            "npm run dev",
            Some(root.to_str().unwrap()),
            "Vite",
            None,
        )
        .unwrap();

        assert_eq!(group.id, "mdt-web");
        assert_eq!(group.name, "Mdt Web");
        assert_eq!(group.kind, "Vite");
        assert_eq!(group.role, "Frontend");

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn auto_groups_worktree_paths_by_project_family() {
        let root = std::env::temp_dir().join(format!(
            "porchlight-worktree-family-test-{}",
            std::process::id()
        ));
        let worktree = root.join("ausmusicfinder-worktrees").join("feature-one");
        std::fs::create_dir_all(&worktree).unwrap();
        std::fs::write(worktree.join("package.json"), r#"{"name":"feature-one"}"#).unwrap();

        let group = auto_group(
            "node",
            "npm run dev",
            Some(worktree.to_str().unwrap()),
            "Vite",
            None,
        )
        .unwrap();

        assert_eq!(group.id, "ausmusicfinder");
        assert_eq!(group.name, "Ausmusicfinder");
        assert_eq!(group.kind, "Vite");

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn auto_groups_different_worktree_families_without_special_cases() {
        let root = std::env::temp_dir().join(format!(
            "porchlight-generic-worktree-family-test-{}",
            std::process::id()
        ));
        let worktree = root.join("customer-portal-worktrees").join("ticket-123");
        std::fs::create_dir_all(&worktree).unwrap();
        std::fs::write(worktree.join("README.md"), "# Ticket 123\n").unwrap();

        let group = auto_group(
            "Python",
            "python manage.py runserver 8033",
            Some(worktree.to_str().unwrap()),
            "Django",
            None,
        )
        .unwrap();

        assert_eq!(group.id, "customer-portal");
        assert_eq!(group.name, "Customer Portal");
        assert_eq!(group.kind, "Django");

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn base_project_and_worktree_project_share_group_id() {
        let root = std::env::temp_dir().join(format!(
            "porchlight-base-and-worktree-test-{}",
            std::process::id()
        ));
        let base = root.join("ausmusicfinder");
        let worktree = root.join("ausmusicfinder-worktrees").join("worktree-1");
        std::fs::create_dir_all(&base).unwrap();
        std::fs::create_dir_all(&worktree).unwrap();

        let base_group = auto_group(
            "Python",
            "python -m http.server 8000",
            Some(base.to_str().unwrap()),
            "Python",
            None,
        )
        .unwrap();
        let worktree_group = auto_group(
            "Python",
            "python -m http.server 8033",
            Some(worktree.to_str().unwrap()),
            "Python",
            None,
        )
        .unwrap();

        assert_eq!(base_group.id, "ausmusicfinder");
        assert_eq!(worktree_group.id, "ausmusicfinder");

        let _ = std::fs::remove_dir_all(root);
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
    fn built_in_rules_group_services_before_project_fallback() {
        let group = auto_group("Plex Media Server", "plex", None, "Plex", None).unwrap();

        assert_eq!(group.id, "plex");
        assert_eq!(group.name, "Plex");
        assert_eq!(group.kind, "Media Server");
        assert_eq!(group.role, "Service");
        assert_eq!(group.source, "classification rule");
    }

    #[test]
    fn app_bundle_fallback_groups_adobe_creative_cloud_node_helper() {
        let command = "/Library/Application Support/Adobe/Creative Cloud Libraries/CCLibrary.app/Contents/MacOS/../libs/node /Library/Application Support/Adobe/Creative Cloud Libraries/CCLibrary.app/Contents/MacOS/../js/server.js";
        let group = auto_group("node", command, None, "Node", None).unwrap();

        assert_eq!(group.id, "adobe-creative-cloud-libraries");
        assert_eq!(group.name, "Adobe Creative Cloud Libraries");
        assert_eq!(group.kind, "Application Service");
        assert_eq!(group.role, "Background Service");
        assert_eq!(group.source, "application bundle path");
    }

    #[test]
    fn app_bundle_fallback_discovers_bundle_icons() {
        let root =
            std::env::temp_dir().join(format!("porchlight-app-icon-test-{}", std::process::id()));
        let resources = root
            .join("Applications")
            .join("Example.app")
            .join("Contents")
            .join("Resources");
        std::fs::create_dir_all(&resources).unwrap();
        let icon = resources.join("app.icns");
        std::fs::write(&icon, []).unwrap();
        let command = format!(
            "{}/Contents/MacOS/Example --server",
            root.join("Applications")
                .join("Example.app")
                .to_string_lossy()
        );

        let group = auto_group("Example", &command, None, "Unknown", None).unwrap();

        assert_eq!(group.id, "example");
        assert_eq!(group.icon.as_deref(), Some(icon.to_str().unwrap()));

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn app_bundle_fallback_groups_regular_application_helpers() {
        let command = "helper /Applications/Figma.app/Contents/MacOS/Figma --server";
        let group = auto_group("Figma", command, None, "Unknown", None).unwrap();

        assert_eq!(group.id, "figma");
        assert_eq!(group.name, "Figma");
        assert_eq!(group.kind, "Application Service");
        assert_eq!(group.role, "Background Service");
        assert_eq!(group.source, "application bundle path");
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
