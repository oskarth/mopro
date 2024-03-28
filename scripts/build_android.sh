#!/bin/bash

# Source the script prelude
source "scripts/_prelude.sh"

# Check if toml-cli is installed
if ! command -v toml &> /dev/null; then
    echo -e "${RED}toml (toml-cli) is not installed. Please install it to continue.${DEFAULT}"
    exit 1
fi

# Function to read value from TOML file and remove quotes
read_toml() {
    toml get "$1" "$2" | tr -d '"'
}

# Check if a configuration file was passed as an argument
if [ "$#" -ne 1 ]; then
    echo -e "\n${RED}Usage: $0 path/to/config.toml${DEFAULT}"
    exit 1
fi

# Read the path to the TOML configuration file from the first argument
CONFIG_FILE="$1"

# Export the configuration file path as an environment variable
export BUILD_CONFIG_PATH="$(pwd)/$CONFIG_FILE"

# Print which configuration file is being used
echo "Using configuration file: $CONFIG_FILE"

# Read configurations from TOML file within [build] block
DEVICE_TYPE=$(read_toml "$CONFIG_FILE" "build.android_device_type")
BUILD_MODE=$(read_toml "$CONFIG_FILE" "build.build_mode")
USE_CIRCOM_WITNESS_RS=$(read_toml "$CONFIG_FILE" "witness.use_witness")

# Determine the architecture and folder based on device type
case $DEVICE_TYPE in
    "x86_64")
        ARCHITECTURE="x86_64-linux-android"
        FOLDER="x86_64"
    ;;
    "x86")
        ARCHITECTURE="i686-linux-android"
        FOLDER="x86"
    ;;
    "arm")
        ARCHITECTURE="armv7-linux-androideabi"
        FOLDER="armeabi-v7a"
    ;;
    "arm64")
        ARCHITECTURE="aarch64-linux-android"
        FOLDER="arm64-v8a"
    ;;
    *)
        echo -e "${RED}Error: Invalid device type specified in config: $DEVICE_TYPE${DEFAULT}"
        exit 1
    ;;
esac

# Determine the library directory and build command based on build mode
case $BUILD_MODE in
    "debug")
        LIB_DIR="debug"
        COMMAND=""
    ;;
    "release")
        LIB_DIR="release"
        COMMAND="--release"
    ;;
    *)
        echo -e "${RED}Error: Invalid build mode specified in config: $BUILD_MODE${DEFAULT}"
        exit 1
    ;;
esac

if [[ "$USE_CIRCOM_WITNESS_RS" == true ]]; then
    WITNESS="--features calc-native-witness"
else
    WITNESS=""
fi

PROJECT_DIR=$(pwd)

cd ${PROJECT_DIR}/mopro-ffi

print_action "[android] Install cargo-ndk"
cargo install cargo-ndk

# Print appropriate message based on device type
print_action "Using $ARCHITECTURE libmopro_ffi.a ($LIB_DIR) static library..."
print_warning "This only works on $FOLDER devices!"

print_action "[android] Build target in $BUILD_MODE mode"
cargo ndk -t ${ARCHITECTURE} build --lib ${COMMAND} ${WITNESS}

print_action "[android] Copy files in mopro-android/Example/jniLibs/"
for binary in ${PROJECT_DIR}/target/*/*/libmopro_ffi.so; do file $binary; done

mkdir -p jniLibs/${FOLDER}/ && \
cp ${PROJECT_DIR}/target/${ARCHITECTURE}/${LIB_DIR}/libmopro_ffi.so jniLibs/${FOLDER}/libuniffi_mopro.so

print_action "[android] Generating Kotlin bindings in $BUILD_MODE mode..."
cargo run --features=uniffi/cli ${COMMAND} \
--bin uniffi-bindgen \
generate src/mopro.udl \
--language kotlin

print_action "[android] Copy Kotlin bindings to mopro-android/Example"
cp -r ${PROJECT_DIR}/mopro-ffi/jniLibs/ ${PROJECT_DIR}/mopro-android/Example/app/src/main/jniLibs/
cp -r ${PROJECT_DIR}/mopro-ffi/src/uniffi/ ${PROJECT_DIR}/mopro-android/Example/app/src/main/java/uniffi/
