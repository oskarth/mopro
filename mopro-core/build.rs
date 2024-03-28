use color_eyre::eyre::eyre;
use color_eyre::eyre::Result;
use enumset::enum_set;
use enumset::EnumSet;
use serde::Deserialize;
use std::path::{Path, PathBuf};
use std::str::FromStr;
use std::{env, fs};
use toml;
use wasmer::{Cranelift, Dylib, Module, Store, Target, Triple};

#[derive(Deserialize)]
struct Config {
    circuit: CircuitConfig,
    dylib: Option<DylibConfig>,
    #[serde(skip)]
    expanded_circuit_dir: Option<String>,
}

#[derive(Deserialize)]
struct CircuitConfig {
    dir: String,
    name: String,
}

#[derive(Deserialize)]
struct DylibConfig {
    use_dylib: bool,
    name: String,
}

/// Resolve a potentially relative path against a base directory.
fn resolve_path(base_dir: &Path, relative_path: &str) -> String {
    let path = Path::new(relative_path);
    if path.is_absolute() {
        relative_path.to_owned()
    } else {
        base_dir.join(path).to_string_lossy().into_owned()
    }
}

impl Config {
    fn resolve_circuit_dir(&self) -> PathBuf {
        let base_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".to_string());
        let circuit_dir = self
            .expanded_circuit_dir
            .as_ref()
            .unwrap_or(&self.circuit.dir);
        Path::new(&base_dir).join(circuit_dir)
    }
}

fn read_config() -> Result<Config> {
    let config_str = match env::var("BUILD_CONFIG_PATH") {
        Ok(config_path) => {
            println!("cargo:rerun-if-changed={}", config_path);
            println!("cargo:warning=BUILD_CONFIG_PATH={}", config_path);
            let config_path = PathBuf::from(config_path);

            // Ensure the config path is absolute or resolve it based on current dir
            let config_path = if config_path.is_absolute() {
                config_path
            } else {
                env::current_dir()?.join(config_path)
            };

            // Read the configuration file
            fs::read_to_string(config_path)?
        }
        Err(_) => {
            println!("cargo:warning=BUILD_CONFIG_PATH not set. Using default configuration.");
            let default_config = r#"
                [circuit]
                dir = "examples/circom/keccak256"
                name = "keccak256_256_test"

                [dylib]
                use_dylib = false
                name = "keccak256.dylib"
            "#;
            default_config.to_string()
        }
    };

    let mut config: Config = toml::from_str(&config_str)?;

    // Resolve paths relative to the config file or default path
    let config_dir = PathBuf::from(env::var("BUILD_CONFIG_PATH").unwrap_or_else(|_| ".".into()));
    let config_dir = config_dir.parent().unwrap_or_else(|| Path::new("."));

    let resolved_circuit_dir = resolve_path(config_dir, &config.circuit.dir);

    config.expanded_circuit_dir = Some(resolved_circuit_dir.clone());

    Ok(config)
}

fn build_dylib(config: &Config) -> Result<()> {
    if let Some(dylib_config) = &config.dylib {
        if dylib_config.use_dylib {
            let project_dir = env::var("CARGO_MANIFEST_DIR")?;
            let out_dir = env::var("OUT_DIR")?;
            let build_mode = env::var("PROFILE")?;
            let target_arch = env::var("TARGET")?;
            let dylib_name = &dylib_config.name;
            let wasm_path = config.resolve_circuit_dir().join(format!(
                "target/{}_js/{}.wasm",
                config.circuit.name, config.circuit.name
            ));

            let out_dir_path = PathBuf::from(out_dir);
            let wasm_file_path = PathBuf::from(wasm_path);
            let dylib_file_path = out_dir_path.join(dylib_name);
            let final_dir_path = PathBuf::from(&project_dir)
                .join("target")
                .join(&target_arch)
                .join(build_mode);

            // Create a WASM engine for the target that can compile
            let triple = Triple::from_str(&target_arch).map_err(|e| eyre!(e))?;
            let cpu_features = enum_set!();
            let target = Target::new(triple, cpu_features);
            let engine = Dylib::new(Cranelift::default()).target(target).engine();

            // Compile the WASM module
            let store = Store::new(&engine);
            let module = Module::from_file(&store, &wasm_file_path)?;

            // Serialize the compiled module to a dylib file
            module.serialize_to_file(&dylib_file_path)?;

            // Ensure the dylib file exists
            assert!(dylib_file_path.exists());

            // Copy dylib to a more predictable path
            fs::create_dir_all(&final_dir_path)?;
            let final_dylib_path = final_dir_path.join(format!("{}.dylib", dylib_name));
            fs::copy(&dylib_file_path, &final_dylib_path)?;

            println!(
                "cargo:rustc-env=BUILD_RS_DYLIB_FILE={}",
                final_dylib_path.display()
            );

            println!(
                "cargo:warning=BUILD_RS_DYLIB_FILE={}",
                final_dylib_path.display()
            );
        } else {
            println!("cargo:warning=Dylib usage is disabled in the config.");
        }
    }
    Ok(())
}

#[cfg(feature = "build-native-witness")]
fn build_witness_graph() -> Result<()> {
    let _ = witness::generate::build_witness();
    let witness_cpp = env::var("WITNESS_CPP").expect("WITNESS_CPP is not set");
    let circuit_file = Path::new(&witness_cpp);
    let circuit_name = circuit_file.file_stem().unwrap().to_str().unwrap();
    let circuit_directory = circuit_file.parent().unwrap();
    println!("cargo:warning=WITNESS_CPP: {}", witness_cpp);
    let graph_path = circuit_directory
        .join("target")
        .join(format!("{}.bin", circuit_name));
    fs::copy("graph.bin", &graph_path).expect("Failed to copy graph.bin");
    Ok(())
}

/// Builds the circuit based on the provided configuration.
///
/// This function assumes that the necessary steps to build the circuit
/// involve checking for the existence of certain files and setting environment variables.
fn build_circuit(config: &Config) -> Result<()> {
    // Check if the current package is mopro-core
    let pkg_name = env::var("CARGO_PKG_NAME").unwrap_or_default();
    let base_dir = if pkg_name == "mopro-core" {
        // If mopro-core, use CARGO_MANIFEST_DIR as base directory
        env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not set")
    } else {
        // Default to current directory
        ".".to_string()
    };

    // Use the expanded circuit directory if available, otherwise fallback to the original directory
    let circuit_dir = config
        .expanded_circuit_dir
        .as_ref()
        .unwrap_or(&config.circuit.dir);
    let circuit_name = &config.circuit.name;

    // Resolve the circuit dictory to an absolute path based on the conditionally set base_dir
    let circuit_dir_path = PathBuf::from(base_dir).join(circuit_dir);

    // Check for the existence of required files
    let zkey_path = circuit_dir_path.join(format!("target/{}_final.zkey", circuit_name));
    let wasm_path =
        circuit_dir_path.join(format!("target/{}_js/{}.wasm", circuit_name, circuit_name));
    let arkzkey_path = circuit_dir_path.join(format!("target/{}_final.arkzkey", circuit_name));
    #[cfg(feature = "calc-native-witness")]
    {
        let graph_path = circuit_dir_path.join(format!("target/{}.bin", circuit_name));

        println!(
            "cargo:warning=BUILD_RS_GRAPH_FILE: {}",
            graph_path.display()
        );
        println!(
            "cargo:rustc-env=BUILD_RS_GRAPH_FILE={}",
            graph_path.display()
        );
    }

    // Ensure the required files exist
    if !zkey_path.exists() || !wasm_path.exists() || !arkzkey_path.exists() {
        return Err(color_eyre::eyre::eyre!(
            "Required files for building the circuit are missing. Did you run `mopro prepare`?"
        ));
    }

    // Set BUILD_RS_* environment variables
    println!("cargo:rustc-env=BUILD_RS_ZKEY_FILE={}", zkey_path.display());
    println!("cargo:rustc-env=BUILD_RS_WASM_FILE={}", wasm_path.display());
    println!(
        "cargo:rustc-env=BUILD_RS_ARKZKEY_FILE={}",
        arkzkey_path.display()
    );

    println!("cargo:warning=BUILD_RS_ZKEY_FILE={}", zkey_path.display());
    println!("cargo:warning=BUILD_RS_WASM_FILE={}", wasm_path.display());
    println!(
        "cargo:warning=BUILD_RS_ARKZKEY_FILE={}",
        arkzkey_path.display()
    );

    Ok(())
}

fn main() -> color_eyre::eyre::Result<()> {
    println!("cargo:rerun-if-env-changed=BUILD_CONFIG_PATH");
    println!("cargo:warning=Preparing circuits...");

    let config = read_config()?;
    #[cfg(feature = "build-native-witness")]
    build_witness_graph()?;
    build_circuit(&config)?;
    build_dylib(&config)?;
    println!("cargo:warning=Successfully prepared circuits.");
    Ok(())
}
