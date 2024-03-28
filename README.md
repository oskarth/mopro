# mopro

Mopro is a toolkit for ZK app development on mobile. Mopro makes client-side proving on mobile simple.

## Getting started

We recommend you use [mopro-cli](https://github.com/oskarth/mopro/tree/main/mopro-cli#mopro-cli) to create and maintain your application. Here's how you can get started with your example app in a few minutes.

You can also watch this short (<5m) [tutorial](https://www.loom.com/share/6ff382b0497c47aea9d0ef8b6e790dd8).

### Install dependencies

First, make sure you've installed the [prerequisites](https://github.com/oskarth/mopro?tab=readme-ov-file#prerequisites).

Then, run the following commands:

```sh
# Clone the mopro repo
git clone git@github.com:oskarth/mopro.git

# Install mopro-cli locally
cd mopro-cli && cargo install --path .

# Set `MOPRO_ROOT` (replace with path to your git checkout of mopro)
# For example: `export MOPRO_ROOT=/Users/user/repos/github.com/oskarth/mopro`
export MOPRO_ROOT=$(PWD)

# Install `mopro` dependencies
mopro deps
```

### Create a project

Create and initialize a project:

```sh
# Create a working directory
mkdir ~/my-zk-app && cd my-zk-app

# Initialize a project
mopro init --platforms ios android

# Go to your project folder
cd mopro-example-app
```

### Configure mopro settings

You may adapt `mopro-config.toml` to your needs. For example, if you already have a Circom project you can use that.

Prepare your circuit artifacts:

```sh
mopro prepare
```

This only has to be done once when changing the circuit.

### Build, test and run your project

Depending on what platforms you are targetting, you can run the following commands:

```sh
# Build the project
mopro build

# Run end-to-end test (in Rust only)
mopro test

# Build the project for iOS
mopro build --platforms ios

# Open in Xcode to run on simulator/device
open ios/ExampleApp/ExampleApp.xcworkspace

# Build the project for Android
mopro build --platforms android

# Open in Android Studio to run on simulator/device
open android -a Android\ Studio
```

See [mopro-cli](https://github.com/oskarth/mopro/tree/main/mopro-cli#mopro-cli) for more details on usage.

## Overview

mopro consists of a set of libraries and utilities. Here's a list of the various subprojects:

- `mopro-cli` - core Rust CLI util.
- `mopro-core` - core mobile Rust library.
- `mopro-ffi` - wraps `mopro-core` and exposes UniFFI bindings.
- `templates/mopro-example-app` - example multi-platform app template.
- `ark-zkey` - helper utility to make zkey more usable and faster in arkworks.
- `mopro-ios` - iOS CocoaPod library exposing native Swift bindings. (will be deprecated)
- `mopro-android` - Android library exposing native Kotlin bindings. (will be deprecated)
- `webprover` - Prove example circuits through a browser, used for benchmarking.
- `scripts` - various helper scripts for `mopro-cli` and testing.

## Architecture

The following illustration shows how mopro and its components fit together into the wider ZKP ecosystem:

![mopro architecture](images/mopro_architecture2.png)

## Prerequisites

Depending on what platforms and adapters you use, there are several prerequisites to install before getting started.

- General
    - [Rust](https://www.rust-lang.org/learn/get-started)
- Circom
    - [circom](https://docs.circom.io/)
    - [snarkjs](https://github.com/iden3/snarkjs)
- iOS
    - [Xcode](https://developer.apple.com/xcode/)
    - [CocoaPods](https://cocoapods.org/)
- Android
    - [Android Studio](https://developer.android.com/studio)
    - Also see configuration below

### Android configuration

Some additional configuration is required for Android.

First, install the latest SDK. In Android Studio, go to `SDK Manager > SDK Tools`  and install `NDK (Side by Side)` (see [Android Developer site](https://developer.android.com/studio/projects/install-ndk#default-version)).

After that, set the following  environment variables:

```sh
# Export `$ANDROID_HOME` and change `{USER_NAME}` to your username
export ANDROID_HOME="/Users/{USER_NAME}/Library/Android/sdk"

# Locate which NDK version you have
ls $ANDROID_HOME/ndk # => 26.1.10909125

# Set it to your `NDK_PATH` environment variable
NDK_PATH=$ANDROID_HOME/ndk/26.1.10909125
```

(Reference: [Running Rust on Android with UniFFI](https://sal.dev/android/intro-rust-android-uniffi/)).

## mopro configuration

This config file is best used together with `mopro-cli`.

By creating a `toml` configuration file you can specify what build settings you want to use. Example is provided in `config-example.toml`:

```toml
# config-example.toml

[build]
# For iOS device_type can be x86_64, simulator, device
ios_device_type = "simulator" # Options: x86_64, simulator, device
# For Android device_type can be x86_64, x86, arm, arm64
android_device_type = "arm64" # Options: x86_64, x86, arm, arm64

# debug is for Rust library to be in debug mode and release for release mode
# We recommend release mode by default for performance
build_mode = "release"    # Options: debug, release

[circuit]
dir = "examples/circom/keccak256" # Directory of the circuit
name = "keccak256_256_test"       # Name of the circuit

[dylib]
use_dylib = false         # Options: true, false
name = "keccak256.dylib" # Name of the dylib file, only used if use_dylib is true

# Note: circom-witness-rs is experimental
# See https://github.com/oskarth/mopro/issues/32 for updates
# Only works for keccak256_256_test circuit now
[witness]
use_witness = false       # Options: true, false
```

## Community and Talks

Join the Telegram group [here](https://t.me/zkmopro).

Talk by @oskarth at ProgCrypto/Devconnect (Istanbul, November 2023): [Slides](https://docs.google.com/presentation/d/1afIEgm8oYRvteWxUd04CcMOxChAiHaD55d5AKd0RkvY/edit#slide=id.g284ac8f47d5_2_24) (no video)

Talk by @oskarth at ETHTaipei (Taipei, March 2024): [Slides](https://hackmd.io/@oskarth/S1yGjF8C6#), [Video](https://www.youtube.com/live/JB6zP9enkbc?si=04xz9XRLkChNiupw&t=14708)

## Contribute

Contributions of all kinds welcome! Please see open GH issues. Also feel free to join the Telegram chat.

## Performance

Preliminary benchmarks on an iPhone 14 Max Pro:

- Keccak256 (150k constraints): 1.5s
    - ~x10-20 faster vs comparable circuit in browser
- anon-aadhaar / RSA Verify: ~6.5s
    - ~5s for witness generation (still in WASM), ~2s prover time
    - 80% of time on witness generation
    - ~x10 faster vs browser on phone
- Bottlenecks: loading zkey and wasm witness generation

See [Project MoPerf results](https://hackmd.io/5ItB2D50QcavF18cWIrmfQ?view=#tip1) for more benchmarks.

## Acknowledgements

This work is sponsored by a joint grant from [PSE](https://pse.dev/) and [0xPARC](https://0xparc.org/).