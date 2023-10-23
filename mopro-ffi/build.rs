use mopro_core::middleware::circom;
use std::env;
use std::path::Path;

// TODO: More general name?
pub fn initialize_witness_calculator(path: &Path) {
    println!(
        "cargo:warning=Initializing witness calculator with path: {}",
        path.display()
    );
    circom::initialize(path);
}

fn main() {
    uniffi::generate_scaffolding("src/mopro.udl").expect("Building the UDL file failed");

    // XXX: We probably want this to be read from environment variable
    // Also this should work from iOS too
    //    let dylib_path = "../mopro-core/target/debug/keccak256.dylib";

    // XXX Try this
    let out_dir = env::var("TARGET_DIR").unwrap();
    //let out_dir = env::var("OUT_DIR").unwrap();

    let out_dir = Path::new(&out_dir).to_path_buf();
    //    let out_dir = out_dir.join(env::var("TARGET").unwrap());
    //    let out_dir = out_dir.join(env::var("BUILD_MODE").unwrap());
    println!(
        "cargo:warning=TARGET_DIR (mopro-ffi): {}",
        out_dir.display()
    );
    let dylib_file = out_dir.join("keccak256.dylib");
    //let dylib_path = "../mopro-core/target/debug/keccak256.dylib";

    // Then what?
    initialize_witness_calculator(&dylib_file);
}
