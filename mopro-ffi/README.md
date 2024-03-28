# mopro-ffi

Thin wrapper around `mopro-core`, exposes UniFFI bindings to be used by `rust-ios`, etc.

## Overview

TBD.

## Development

### Prerequisites

1. Ensure you have Rust installed
2. Add platform targets `rustup target add x86_64-apple-ios aarch64-apple-ios aarch64-apple-ios-sim`
3. Install `uniffi-bindgen` locally with `cargo install --bin uniffi-bindgen --path .`
4. In order to locally run the bindings tests, you will need
    * Kotlin:
        * `kotlinc`, the [Kotlin command-line compiler](https://kotlinlang.org/docs/command-line.html).
        * `ktlint`, the [Kotlin linter used to format the generated bindings](https://ktlint.github.io/).
        * The [Java Native Access](https://github.com/java-native-access/jna#download) JAR downloaded and its path
            added to your `$CLASSPATH` environment variable.
    * Swift:
        * `swift` and `swiftc`, the [Swift command-line tools](https://swift.org/download/).
        * The Swift `Foundation` package.

### Platforms supported

Currently iOS is the main target, but Android will soon follow. PRs welcome.

### Building

Run `make` to build debug and release static libraries for supported platforms.

### Generate UniFFI bindings

The following command generates Swift bindings:

`uniffi-bindgen generate src/mopro.udl --language swift --out-dir target/SwiftBindings`

## Test bindings

To test bindings:

`cargo test --test test_generated_bindings`

To test bindings in release mode without warning:

`cargo test --test test_generated_bindings --release 2>/dev/null`

## Generate MSM benchmark report in swift on laptop

1. Comment `default=[]` and uncomment `default=["gpu-benchmarks"]` to enable `gpu-benchmarks` feature flag
2. run `RUSTFLAGS="-C opt-level=3" cargo test --test test_generated_bindings --release`
3. The report will be generated at `mopro-core/benchmarks/gpu_explorations/msm_bench_swift_laptop.csv`

![msm benchmarks of time (rust vs. swift)](https://hackmd.io/_uploads/BkxRMMtca.png)

The above report was conducted on an M1 Pro MacBook Pro.

For more information, read this report we have completed, which compares the time performance of MSM running in rust and swift.

## To use [circom-witness-rs](https://github.com/philsippl/circom-witness-rs) (Experimental)
1. Comment `default=[]` and uncomment `default = ["calc-native-witness"]` to enable `calc-native-witness` feature flag
2. Test with
   ```sh
   # Run all tests
   cargo test --features calc-native-witness
   # Run bindings tests
   cargo test --test test_generated_bindings --features calc-native-witness
   ```