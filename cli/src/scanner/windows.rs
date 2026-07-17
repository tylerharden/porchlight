use super::ScannerError;
use crate::config::Config;
use crate::model::LocalServer;

pub fn scan(_config: &Config) -> Result<Vec<LocalServer>, ScannerError> {
    Err(ScannerError::UnsupportedPlatform)
}
