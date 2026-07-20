use super::{display_directory, ScannerError};
use crate::classification::{discover_project_icon, infer_server_group};
use crate::config::Config;
use crate::model::{infer_server_type_for_project, LocalServer, ServerStatus};
use std::collections::HashSet;
use std::path::Path;
use std::process::Command;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LsofListener {
    pub process_name: String,
    pub pid: u32,
    pub port: u16,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ProcessDetails {
    command: String,
    working_directory: Option<String>,
    open_paths: Vec<String>,
}

pub fn scan(config: &Config) -> Result<Vec<LocalServer>, ScannerError> {
    let output = run_command("/usr/sbin/lsof", &["-nP", "-iTCP", "-sTCP:LISTEN"])?;
    let listeners = parse_lsof_listeners(&output);
    let mut servers = Vec::new();
    let mut seen = HashSet::new();

    for listener in listeners {
        if !seen.insert((listener.port, listener.pid)) {
            continue;
        }

        let Ok(process) = process_details(listener.pid) else {
            continue;
        };
        let live_server_directory = vscode_live_server_directory(listener.port, &process);
        let is_vscode_live_server = live_server_directory.is_some();
        let working_directory = live_server_directory.or(process.working_directory);

        if config.excluded_port_set().contains(&listener.port) {
            continue;
        }

        if !is_vscode_live_server
            && !config.includes(
                &listener.process_name,
                &process.command,
                working_directory.as_deref(),
                listener.port,
            )
        {
            continue;
        }

        let server_type = if is_vscode_live_server {
            "Live Server".to_string()
        } else {
            infer_server_type_for_project(
                &listener.process_name,
                &process.command,
                working_directory.as_deref(),
            )
        };
        let icon = working_directory.as_deref().and_then(discover_project_icon);
        let display_directory = working_directory.as_deref().map(display_directory);

        let start_command = process.command.clone();

        let mut server = LocalServer {
            id: server_id(listener.port, working_directory.as_deref()),
            port: listener.port,
            pid: listener.pid,
            status: ServerStatus::Active,
            process_name: listener.process_name,
            server_type,
            icon,
            group: None,
            command: process.command,
            working_directory,
            display_directory,
            url: format!("http://localhost:{}", listener.port),
            pinned: false,
            hidden: false,
            last_seen_at: None,
            start_command: Some(start_command),
        };
        server.group = infer_server_group(&server, config.show_automatic_groups);
        servers.push(server);
    }

    servers.sort_by_key(|server| (server.port, server.pid));
    Ok(servers)
}

pub fn parse_lsof_listeners(output: &str) -> Vec<LsofListener> {
    output
        .lines()
        .skip(1)
        .filter_map(|line| {
            let fields = line.split_whitespace().collect::<Vec<_>>();
            let process_name = fields.first()?;
            let pid = fields.get(1)?.parse().ok()?;
            let name = fields.get(8)?;
            let port = parse_port(name)?;

            Some(LsofListener {
                process_name: (*process_name).to_string(),
                pid,
                port,
            })
        })
        .collect()
}

fn parse_port(name: &str) -> Option<u16> {
    let (_, port_and_suffix) = name.rsplit_once(':')?;
    let port = port_and_suffix
        .chars()
        .take_while(|character| character.is_ascii_digit())
        .collect::<String>();

    port.parse().ok()
}

fn process_details(pid: u32) -> Result<ProcessDetails, ScannerError> {
    let pid_text = pid.to_string();
    let command = run_command("/bin/ps", &["-p", &pid_text, "-o", "command="])?
        .trim()
        .to_string();

    let cwd_output = run_command(
        "/usr/sbin/lsof",
        &["-a", "-p", &pid_text, "-d", "cwd", "-Fn"],
    )
    .ok();
    let working_directory = cwd_output.and_then(|output| {
        output
            .lines()
            .find_map(|line| line.strip_prefix('n').map(ToString::to_string))
    });

    let open_paths = if looks_like_vscode_helper(&command) {
        run_command("/usr/sbin/lsof", &["-a", "-p", &pid_text, "-Fn"])
            .ok()
            .map(parse_lsof_names)
            .unwrap_or_default()
    } else {
        vec![]
    };

    Ok(ProcessDetails {
        command,
        working_directory,
        open_paths,
    })
}

fn parse_lsof_names(output: String) -> Vec<String> {
    output
        .lines()
        .filter_map(|line| line.strip_prefix('n').map(ToString::to_string))
        .collect()
}

fn vscode_live_server_directory(port: u16, process: &ProcessDetails) -> Option<String> {
    if !(5500..=5599).contains(&port) {
        return None;
    }

    if !looks_like_vscode_helper(&process.command) {
        return None;
    }

    if !process
        .open_paths
        .iter()
        .any(|path| path.contains("/.vscode/extensions/ritwickdey.liveserver-"))
    {
        return None;
    }

    process
        .open_paths
        .iter()
        .filter(|path| path.starts_with('/'))
        .filter(|path| path.as_str() != "/")
        .filter(|path| !path.contains("/Library/"))
        .filter(|path| !path.contains("/.vscode/"))
        .filter(|path| !path.contains("/Applications/"))
        .filter(|path| Path::new(path).is_dir())
        .max_by_key(|path| path.len())
        .cloned()
}

fn looks_like_vscode_helper(command: &str) -> bool {
    let command = command.to_lowercase();
    command.contains("visual studio code.app") || command.contains("code helper")
}

fn run_command(executable: &str, arguments: &[&str]) -> Result<String, ScannerError> {
    let output = Command::new(executable)
        .args(arguments)
        .output()
        .map_err(|error| ScannerError::Command {
            command: format_command(executable, arguments),
            message: error.to_string(),
        })?;

    if !output.status.success() {
        return Err(ScannerError::Command {
            command: format_command(executable, arguments),
            message: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        });
    }

    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

fn format_command(executable: &str, arguments: &[&str]) -> String {
    std::iter::once(executable)
        .chain(arguments.iter().copied())
        .collect::<Vec<_>>()
        .join(" ")
}

fn server_id(port: u16, working_directory: Option<&str>) -> String {
    format!("{}:{}", port, working_directory.unwrap_or("unknown"))
}

#[cfg(test)]
mod tests {
    use super::{parse_lsof_listeners, vscode_live_server_directory, LsofListener, ProcessDetails};

    #[test]
    fn parses_lsof_listener_rows() {
        let output = r#"COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
node    12345 tyler  21u  IPv4 123456      0t0  TCP *:5501 (LISTEN)
Python  23456 tyler  10u  IPv4 234567      0t0  TCP 127.0.0.1:8000 (LISTEN)
"#;

        assert_eq!(
            parse_lsof_listeners(output),
            vec![
                LsofListener {
                    process_name: "node".into(),
                    pid: 12345,
                    port: 5501,
                },
                LsofListener {
                    process_name: "Python".into(),
                    pid: 23456,
                    port: 8000,
                },
            ]
        );
    }

    #[test]
    fn detects_vscode_live_server_directory_from_open_paths() {
        let root = std::env::temp_dir().join(format!(
            "porchlight-vscode-live-server-test-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&root).unwrap();

        let process = ProcessDetails {
            command: "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)".into(),
            working_directory: Some("/".into()),
            open_paths: vec![
                "/Users/tyler/.vscode/extensions/ritwickdey.liveserver-5.7.10/node_modules/fsevents/fsevents.node".into(),
                root.to_string_lossy().to_string(),
            ],
        };

        assert_eq!(
            vscode_live_server_directory(5501, &process).as_deref(),
            Some(root.to_str().unwrap())
        );

        let _ = std::fs::remove_dir_all(root);
    }
}
