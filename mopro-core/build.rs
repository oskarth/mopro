use color_eyre::eyre::Result;

// NOTE: This is just a build test for middleware/circom/mod.rs to turn it a dylib
// This is done to deal with memory restrictions on iOS

// Inspired by https://github.com/worldcoin/semaphore-rs/blob/main/build.rs
// #[cfg(feature = "dylib")]
// fn build_dylib() -> Result<()> {
//     use color_eyre::eyre::eyre;
//     use enumset::enum_set;
//     use enumset::EnumSet;
//     use std::path::Path;
//     use std::{env, str::FromStr};

//     use wasmer::{Module, Store, Target, Triple};

//     use wasmer_compiler_cranelift::Cranelift;
//     use wasmer_engine_dylib::Dylib;

//     let wasm_path = "./../mopro-core/examples/circom/keccak256/target/keccak256_256_test_js/keccak256_256_test.wasm";
//     let wasm_file = Path::new(wasm_path).to_path_buf();

//     //let out_path = "./target/debug/";

//     // XXX: Try this
//     let out_dir = env::var("TARGET_DIR")?;
//     //let out_dir = env::var("OUT_DIR")?;

//     let out_dir = Path::new(&out_dir).to_path_buf();
//     //    let out_dir = out_dir.join(env::var("TARGET").unwrap());
//     //    let out_dir = out_dir.join(env::var("BUILD_MODE").unwrap());
//     println!(
//         "cargo:warning=TARGET_DIR (mopro-core): {}",
//         out_dir.display()
//     );
//     let dylib_file = out_dir.join("keccak256.dylib");

//     println!(
//         "cargo:rustc-env=CIRCUIT_WASM_DYLIB={}",
//         dylib_file.display()
//     );

//     // if dylib_file.exists() {
//     //     return Ok(());
//     // }

//     // Create a WASM engine for the target that can compile
//     let triple = Triple::from_str(&env::var("TARGET")?).map_err(|e| eyre!(e))?;
//     println!("cargo:warning=TRIPLE TARGET (mopro-core): {}", triple);

//     let real_device = &env::var("TARGET").unwrap() == "aarch64-apple-ios";
//     println!("cargo:warning=REAL DEVICE (mopro-core): {}", real_device);

//     //    if real_device {
//     // println!(
//     //     "cargo:warning=Building for real device (mopro-core): {}",
//     //     real_device
//     // );

//     let cpu_features = enum_set!();
//     let target = Target::new(triple, cpu_features);
//     let engine = Dylib::new(Cranelift::default()).target(target).engine();

//     // Compile the WASM module
//     let store = Store::new(&engine);
//     let module = Module::from_file(&store, &wasm_file).unwrap();
//     module.serialize_to_file(&dylib_file).unwrap();
//     assert!(dylib_file.exists());
//     println!("cargo:warning=Circuit dylib is in {}", dylib_file.display());

//     Ok(())
// }

fn main() -> Result<()> {
    // #[cfg(feature = "dylib")]
    // build_dylib()?;
    Ok(())
}
