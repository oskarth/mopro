#!/bin/bash

# Source the script prelude
source "scripts/_prelude.sh"

# Assert we're in the project root
if [[ ! -d "mopro-ffi" || ! -d "mopro-core" || ! -d "mopro-ios" ]]; then
    echo -e "${RED}Error: This script must be run from the project root directory that contains mopro-ffi, mopro-core, and mopro-ios folders.${DEFAULT}"
    exit 1
fi

PROJECT_DIR=$(pwd)
CIRCOM_DIR="${PROJECT_DIR}/mopro-core/examples/circom"

compile_circuit() {
    local circuit_dir=$1
    local circuit_file=$2
    local target_file="$circuit_dir/target/$(basename $circuit_file .circom).r1cs"

    print_action "[core/circom] Compiling $circuit_file example circuit..."
    if [ ! -f "$target_file" ]; then
        ./scripts/compile.sh $circuit_dir $circuit_file
    else
        echo "File $target_file already exists, skipping compilation."
    fi
}

npm_install() {
    local circuit_dir=$1

    if [[ ! -d "$circuit_dir/node_modules" ]]; then
        echo "Installing npm dependencies for $circuit_dir..."
        (cd $circuit_dir && npm install)
    fi
}

# Check for target support
check_target_support() {
    rustup target list | grep installed | grep -q "$1"
}

download_files() {
    local url="https://mopro.vivianjeng.xyz"
    local dir=$1
    local circuit=$2
    local target_dir="${CIRCOM_DIR}/${dir}/target"
    local js_target_dir="${target_dir}/${circuit}_js"

    # Create directories if they don't exist
    mkdir -p "$target_dir" "$js_target_dir"

    # Check if file exists
    # Download files to the specified directories
    if ! [ -f "${target_dir}/${circuit}_final.arkzkey" ]; then
        wget -P "$target_dir" "${url}/${circuit}_final.arkzkey"
    else
        echo "File ${circuit}_final.arkzkey already exists, skipping download."
    fi

    if ! [ -f "${target_dir}/${circuit}_final.zkey" ]; then
        wget -P "$target_dir" "${url}/${circuit}_final.zkey"
    else
        echo "File ${circuit}_final.zkey already exists, skipping download."
    fi

    if ! [ -f "${js_target_dir}/${circuit}.wasm" ]; then
        wget -P "$js_target_dir" "${url}/${circuit}.wasm"
    else
        echo "File ${circuit}.wasm already exists, skipping download."
    fi
    
}
# TODO: Comment out compile_circuit stuff again once zkey is integrated and we don't need r1cs file anymore

# NOTE: On CI instead of compiling circuits and running trusted setup
# We just download test artifacts and use these
# We thus skip all of the below steps that are run locally in `prepare.sh`
print_action "[core/circom] Downloading artifacts for example circuits..."

# Build Circom circuits in mopro-core and run trusted setup
print_action "[core/circom] Compiling example circuits..."
cd $CIRCOM_DIR

# Compile multiplier2
compile_circuit multiplier2 multiplier2.circom

# Setup and compile keccak256
npm_install keccak256
compile_circuit keccak256 keccak256_256_test.circom

# Setup and compile rsa
npm_install rsa
compile_circuit rsa main.circom

# # Run trusted setup for multiplier2
# print_action "[core/circom] Running trusted setup for multiplier2..."
# ./scripts/trusted_setup.sh multiplier2 08 multiplier2
#
# # Run trusted setup for keccak256
# print_action "[core/circom] Running trusted setup for keccak256..."
# ./scripts/trusted_setup.sh keccak256 18 keccak256_256_test

print_action "[core/circom] Downloading artifacts for multiplier2..."
download_files "multiplier2" "multiplier2"

print_action "[core/circom] Downloading artifacts for keccak256..."
download_files "keccak256" "keccak256_256_test"

print_action "[core/circom] Downloading artifacts for rsa..."
download_files "rsa" "main"

# Add support for target architectures
print_action "[ffi] Adding support for target architectures..."
cd ${PROJECT_DIR}/mopro-ffi

for target in x86_64-apple-ios aarch64-apple-ios aarch64-apple-ios-sim aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android; do
    if ! check_target_support $target; then
        rustup target add $target
    else
        echo "Target $target already installed, skipping."
    fi
done

# Install toml-cli binary
print_action "[config] Installing toml-cli..."
if ! command -v toml &> /dev/null
then
    cargo install toml-cli
else
    echo "toml already installed, skipping."
fi

# Install uniffi-bindgen binary in mopro-ffi
print_action "[ffi] Installing uniffi-bindgen..."
if ! command -v uniffi-bindgen &> /dev/null
then
    cargo install --bin uniffi-bindgen --path .
else
    echo "uniffi-bindgen already installed, skipping."
fi

print_action "Done! Please run ./scripts/buld_ios.sh to build for iOS."
