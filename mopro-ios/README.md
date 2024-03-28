# mopro-ios

## Prepare

<!--TODO: If the monorepo is seperated, update this-->

Check the [Prepare](../README.md#prepare) and [Build Bindings](../README.md#build-bindings) steps in the root directory.

## Execute

Open the `MoproKit/Example/MoproKit.xcworkspace` in Xcode.
Use `command`+`R` to execute a simulator.

## Linker problems?

Add the following settings after

1. `MoproKit/Example/Pods/Target Support Files/MoproKit/MoproKit.debug.xcconfig`
2. `MoproKit/Example/Pods/Target Support Files/MoproKit/MoproKit.release.xcconfig`

files

```
LIBRARY_SEARCH_PATHS=${SRCROOT}/../../Libs
OTHER_LDFLAGS=-lmopro_ffi
USER_HEADER_SEARCH_PATHS=${SRCROOT}/../../include
```

## Tests for the example app

There are two ways to run tests for the example app:

1. Xcode
   Open the `MoproKit/Example/MoproKit.xcworkspace` in Xcode.
   Use `command`+`U` to run tests.

2. CLI
   Run tests with command line:

    ```sh
    cd MoproKit/Example
    xcodebuild test -scheme MoproKit-Example \
                    -workspace MoproKit.xcworkspace \
                    -destination "platform=iOS Simulator,OS=17.0.1,name=iPhone 15 Pro"
    ```

    Check your simulator version and the OS with:

    ```sh
    xcodebuild -showdestinations -workspace MoproKit.xcworkspace -scheme MoproKit-Example
    ```

## Run MSM Benchmark

1. `cd mopro-ffi/` and convert `default=[]` into `default=["gpu-benchmarks"]` to enable `gpu-benchmarks` feature flag
2. run `make` to build the mopro-ffi library
3. `cd mopro/` and run `./scripts/build_ios.sh config-example.toml` to build IOS app and link
   * remember to alter the `ios_device_type` in `config-example.toml`
   * `simulator`: running on the simulator (default)
   * `device`: running on a real IOS device
4. Open `MoproKit/Example/MoproKit.xcworkspace` in Xcode and `cmd + R` for building

## Dylib support

When building for real devices on iOS we have to convert the `wasm` witness generation file to a `dylib`.
When doing so, set the `use_dylib` flag to true in `mopro-config.toml`.

After building, make sure to Embed Circuit under Build Phases. Add `CircuitBindings.xcframework` to the "Embed Circuit" phase under ExampleApp -> Build Phases.