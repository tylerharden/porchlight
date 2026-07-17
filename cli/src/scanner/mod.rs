use crate::config::Config;
use crate::model::LocalServer;
use thiserror::Error;

#[cfg(target_os = "macos")]
mod macos;

#[cfg(target_os = "linux")]
mod linux;

#[cfg(target_os = "windows")]
mod windows;

#[derive(Debug, Error)]
pub enum ScannerError {
    #[error("failed to run {command}: {message}")]
    Command { command: String, message: String },
    #[error("server scanning is not implemented for this platform yet")]
    UnsupportedPlatform,
}

pub fn scan(config: &Config) -> Result<Vec<LocalServer>, ScannerError> {
    #[cfg(target_os = "macos")]
    {
        return macos::scan(config);
    }

    #[cfg(target_os = "linux")]
    {
        return linux::scan(config);
    }

    #[cfg(target_os = "windows")]
    {
        return windows::scan(config);
    }

    #[allow(unreachable_code)]
    Err(ScannerError::UnsupportedPlatform)
}

pub fn display_directory(path: &str) -> String {
    if let Some(home) = std::env::var_os("HOME") {
        let home = home.to_string_lossy();
        if path == home {
            return "~".to_string();
        }

        if let Some(rest) = path.strip_prefix(&format!("{home}/")) {
            return format!("~/{rest}");
        }
    }

    path.to_string()
}
