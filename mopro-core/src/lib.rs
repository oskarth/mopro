pub mod middleware;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum MoproError {
    #[error("CircomError: {0}")]
    CircomError(String),
    #[error("IoError: {0}")]
    IoError(String),
}
