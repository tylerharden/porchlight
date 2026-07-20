use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize)]
pub struct Config {
    pub keywords: Vec<String>,
    pub excluded_ports: Vec<u16>,
    pub excluded_patterns: Vec<String>,
    pub refresh_interval_seconds: u64,
    pub show_recents: bool,
    pub show_automatic_groups: bool,
    pub recent_ttl_minutes: Option<u64>,
}

#[derive(Debug, Clone, Default, Deserialize, Serialize)]
struct UserConfig {
    show_automatic_groups: Option<bool>,
    recent_ttl_minutes: Option<u64>,
}

impl Config {
    pub fn load() -> Result<Self, ConfigError> {
        let mut config = Self::default();
        let user_config = load_user_config()?;

        if let Some(show_automatic_groups) = user_config.show_automatic_groups {
            config.show_automatic_groups = show_automatic_groups;
        }
        config.recent_ttl_minutes = user_config.recent_ttl_minutes;

        Ok(config)
    }

    pub fn set_show_automatic_groups(value: bool) -> Result<(), ConfigError> {
        let mut user_config = load_user_config()?;
        user_config.show_automatic_groups = Some(value);
        save_user_config(&user_config)
    }

    pub fn set_recent_ttl_minutes(value: Option<u64>) -> Result<(), ConfigError> {
        let mut user_config = load_user_config()?;
        user_config.recent_ttl_minutes = value;
        save_user_config(&user_config)
    }

    pub fn excluded_port_set(&self) -> HashSet<u16> {
        self.excluded_ports.iter().copied().collect()
    }

    pub fn includes(
        &self,
        process_name: &str,
        command: &str,
        working_directory: Option<&str>,
        port: u16,
    ) -> bool {
        if self.excluded_port_set().contains(&port) {
            return false;
        }

        let haystack = format!(
            "{} {} {}",
            process_name,
            command,
            working_directory.unwrap_or_default()
        )
        .to_lowercase();

        if self
            .excluded_patterns
            .iter()
            .any(|pattern| haystack.contains(&pattern.to_lowercase()))
        {
            return false;
        }

        self.keywords
            .iter()
            .any(|keyword| haystack.contains(&keyword.to_lowercase()))
    }
}

fn load_user_config() -> Result<UserConfig, ConfigError> {
    let path = config_path();
    if !path.exists() {
        return Ok(UserConfig::default());
    }

    let contents = std::fs::read_to_string(&path).map_err(|source| ConfigError::Read {
        path: path.display().to_string(),
        source,
    })?;

    serde_json::from_str(&contents).map_err(|source| ConfigError::Parse {
        path: path.display().to_string(),
        source,
    })
}

fn save_user_config(config: &UserConfig) -> Result<(), ConfigError> {
    let path = config_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|source| ConfigError::Write {
            path: parent.display().to_string(),
            source,
        })?;
    }

    let contents = serde_json::to_string_pretty(config).expect("config serializes");
    std::fs::write(&path, format!("{contents}\n")).map_err(|source| ConfigError::Write {
        path: path.display().to_string(),
        source,
    })
}

pub fn config_path() -> PathBuf {
    let home = std::env::var_os("HOME").unwrap_or_else(|| ".".into());
    PathBuf::from(home)
        .join(".config")
        .join("porchlight")
        .join("config.json")
}

#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("failed to read config file {path}: {source}")]
    Read {
        path: String,
        source: std::io::Error,
    },
    #[error("failed to parse config file {path}: {source}")]
    Parse {
        path: String,
        source: serde_json::Error,
    },
    #[error("failed to write config file {path}: {source}")]
    Write {
        path: String,
        source: std::io::Error,
    },
}

impl Default for Config {
    fn default() -> Self {
        Self {
            keywords: vec![
                "python".into(),
                "php".into(),
                "ruby".into(),
                "vite".into(),
                "live".into(),
                "serve".into(),
                "http".into(),
                "next".into(),
                "nuxt".into(),
                "astro".into(),
                "django".into(),
                "flask".into(),
                "rails".into(),
                "uvicorn".into(),
                "gunicorn".into(),
                "deno".into(),
            ],
            excluded_ports: vec![],
            excluded_patterns: vec![
                "Code Helper".into(),
                "OpenCode Helper".into(),
                "Visual Studio Code.app".into(),
                "/.vscode/extensions/".into(),
                "atlassian_cli_rovodev".into(),
                "Inference.Service.Agent".into(),
            ],
            refresh_interval_seconds: 5,
            show_recents: true,
            show_automatic_groups: true,
            recent_ttl_minutes: None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::Config;

    #[test]
    fn filters_by_keyword_and_excluded_port() {
        let config = Config {
            keywords: vec!["vite".into()],
            excluded_ports: vec![5501],
            excluded_patterns: vec!["Code Helper".into()],
            refresh_interval_seconds: 5,
            show_recents: true,
            show_automatic_groups: true,
            recent_ttl_minutes: None,
        };

        assert!(config.includes("node", "vite --host", Some("/Users/tyler/project"), 5173));
        assert!(!config.includes("node", "vite --host", Some("/Users/tyler/project"), 5501));
        assert!(!config.includes(
            "Code Helper",
            "vite --host",
            Some("/Users/tyler/project"),
            5173
        ));
        assert!(!config.includes("postgres", "postgres", Some("/Users/tyler/project"), 5432));
    }
}
