use serde::Serialize;

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
pub enum ServerStatus {
    Active,
    Recent,
    Stopped,
    Unknown,
}

pub fn infer_server_type(process_name: &str, command: &str) -> String {
    let haystack = format!("{process_name} {command}").to_lowercase();

    let server_type = if haystack.contains("manage.py") && haystack.contains("runserver") {
        "Django"
    } else if haystack.contains("live-server") {
        "Live Server"
    } else if haystack.contains("next") && haystack.contains("dev") {
        "Next.js"
    } else if haystack.contains("nuxt") && haystack.contains("dev") {
        "Nuxt"
    } else if haystack.contains("astro") && haystack.contains("dev") {
        "Astro"
    } else if haystack.contains("rails") && (haystack.contains("server") || haystack.contains(" s ")) {
        "Rails"
    } else if haystack.contains("uvicorn") {
        "Uvicorn"
    } else if haystack.contains("gunicorn") {
        "Gunicorn"
    } else if haystack.contains("vite") {
        "Vite"
    } else if haystack.contains("php -s") {
        "PHP"
    } else if haystack.contains("bun") {
        "Bun"
    } else if haystack.contains("deno") {
        "Deno"
    } else if haystack.contains("python") {
        "Python"
    } else if haystack.contains("node") {
        "Node"
    } else if process_name.trim().is_empty() {
        "Unknown"
    } else {
        process_name
    };

    server_type.to_string()
}

#[cfg(test)]
mod tests {
    use super::infer_server_type;

    #[test]
    fn infers_common_server_types() {
        assert_eq!(infer_server_type("Python", "python manage.py runserver 8000"), "Django");
        assert_eq!(infer_server_type("node", "npm exec vite --host"), "Vite");
        assert_eq!(infer_server_type("node", "next dev"), "Next.js");
        assert_eq!(infer_server_type("ruby", "rails server"), "Rails");
        assert_eq!(infer_server_type("python", "uvicorn app:app"), "Uvicorn");
        assert_eq!(infer_server_type("node", "live-server --port=5501"), "Live Server");
    }

    #[test]
    fn falls_back_to_process_name() {
        assert_eq!(infer_server_type("postgres", "postgres"), "postgres");
        assert_eq!(infer_server_type("", ""), "Unknown");
    }
}
