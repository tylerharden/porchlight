use serde::Serialize;
use std::collections::HashSet;

#[derive(Debug, Clone, Serialize)]
pub struct Config {
    pub keywords: Vec<String>,
    pub excluded_ports: Vec<u16>,
    pub excluded_patterns: Vec<String>,
    pub refresh_interval_seconds: u64,
    pub show_recents: bool,
    pub recent_ttl_minutes: u64,
}

impl Config {
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
            recent_ttl_minutes: 120,
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
            recent_ttl_minutes: 120,
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
