pub mod middleware;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum MoproError {
    #[error("CircomError: {0}")]
    CircomError(String),
}

#[cfg(feature = "dylib")]
pub use crate::middleware::circom::initialize;
