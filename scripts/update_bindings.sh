#!/bin/bash

# Deal with errors
set -euo pipefail

# Color definitions
DEFAULT='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
GREY='\033[0;90m'

# Coloring the -x output (commands)
DEBUG_COLOR="${DEFAULT}"
trap 'echo -e ${DEBUG_COLOR}${BASH_COMMAND}${DEFAULT}' DEBUG

# Function to handle exit
handle_exit() {
    # $? is a special variable that holds the exit code of the last command executed
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}Script did not finish successfully!${DEFAULT}"
    fi
}

# Set the trap
trap handle_exit EXIT

print_action() {
    printf "\n${GREEN}$1${DEFAULT}\n"
}

print_warning() {
    printf "\n${YELLOW}$1${DEFAULT}\n"
}

# Assert we're in the project root
if [[ ! -d "mopro-ffi" || ! -d "mopro-core" || ! -d "mopro-ios" ]]; then
    echo -e "${RED}Error: This script must be run from the project root directory that contains mopro-ffi, mopro-core, and mopro-ios folders.${DEFAULT}"
    exit 1
fi

# Ensure there are at least two arguments
if [[ $# -lt 2 ]]; then
    echo -e "${RED}Error: Please specify the device type ('simulator' or 'device') and build mode ('debug' or 'release') as arguments.${DEFAULT}"
    exit 1
fi

# Check for the device type argument
if [[ "$1" == "x86_64" ]]; then
    DEVICE_TYPE="x86_64"
    ARCHITECTURE="x86_64-apple-ios"
elif [[ "$1" == "simulator" ]]; then
    DEVICE_TYPE="simulator"
    ARCHITECTURE="aarch64-apple-ios-sim"
elif [[ "$1" == "device" ]]; then
    DEVICE_TYPE="device"
    ARCHITECTURE="aarch64-apple-ios"
else
    echo -e "${RED}Error: Please specify either 'x86_64', 'simulator' or 'device' as the first argument.${DEFAULT}"
    exit 1
fi

# Check for the build mode argument
if [[ "$2" == "debug" ]]; then
    BUILD_MODE="debug"
    LIB_DIR="debug"
elif [[ "$2" == "release" ]]; then
    BUILD_MODE="release"
    LIB_DIR="release"
else
    echo -e "${RED}Error: Please specify either 'debug' or 'release' as the second argument.${DEFAULT}"
    exit 1
fi

print_action "Updating mopro-ffi bindings and library ($BUILD_MODE $DEVICE_TYPE)..."

PROJECT_DIR=$(pwd)
TARGET_DIR=${PROJECT_DIR}/target
MOPROKIT_DIR=${PROJECT_DIR}/mopro-ios/MoproKit

# For dylib stuff
mkdir -p ${TARGET_DIR}/${ARCHITECTURE}/${BUILD_MODE}
export TARGET_DIR
export BUILD_MODE

print_action "Generating Swift bindings..."
uniffi-bindgen generate ${PROJECT_DIR}/mopro-ffi/src/mopro.udl --language swift --out-dir ${TARGET_DIR}/SwiftBindings

print_action "Building mopro-ffi static library ($BUILD_MODE)..."
cd ${PROJECT_DIR}/mopro-ffi
if [[ "$BUILD_MODE" == "debug" ]]; then
    cargo build --target ${ARCHITECTURE}
elif [[ "$BUILD_MODE" == "release" ]]; then
    cargo build --release --target ${ARCHITECTURE}
fi

# Build dylib
print_action "Building mopro-ffi dynamic library ($BUILD_MODE)..."
cd ${PROJECT_DIR}/mopro-ffi
if [[ "$BUILD_MODE" == "debug" ]]; then
    cargo build --target ${ARCHITECTURE} --features dylib
elif [[ "$BUILD_MODE" == "release" ]]; then
    cargo build --release --target ${ARCHITECTURE} --features dylib
fi

# Print appropriate message based on device type
if [[ "$DEVICE_TYPE" == "x86_64" ]]; then
    print_action "Using $ARCHITECTURE libmopro_ffi.a ($LIB_DIR) static library..."
    print_warning "This only works on iOS simulator (x86_64)"
elif [[ "$DEVICE_TYPE" == "simulator" ]]; then
    print_action "Using $ARCHITECTURE libmopro_ffi.a ($LIB_DIR) static library..."
    print_warning "This only works on iOS simulator (ARM64)"
elif [[ "$DEVICE_TYPE" == "device" ]]; then
    print_action "Using $ARCHITECTURE libmopro_ffi.a ($LIB_DIR) static library..."
    print_warning "This only works on iOS devices (ARM64)"
fi

cp ${PROJECT_DIR}/mopro-ffi/target/${ARCHITECTURE}/${LIB_DIR}/libmopro_ffi.a ${TARGET_DIR}/

# Dylib
cp ${PROJECT_DIR}/mopro-core/target/${ARCHITECTURE}/${LIB_DIR}/rsa.dylib ${TARGET_DIR}/

print_action "Copying Swift bindings and static library to MoproKit..."
cp ${TARGET_DIR}/SwiftBindings/moproFFI.h ${MOPROKIT_DIR}/Include/
cp ${TARGET_DIR}/SwiftBindings/mopro.swift ${MOPROKIT_DIR}/Bindings/
cp ${TARGET_DIR}/SwiftBindings/moproFFI.modulemap ${MOPROKIT_DIR}/Resources/
cp ${TARGET_DIR}/libmopro_ffi.a ${MOPROKIT_DIR}/Libs/

# Dylib
cp ${TARGET_DIR}/rsa.dylib ${MOPROKIT_DIR}/Libs/

# Fix dynamic lib install paths
# NOTE: Xcode might already do this for us
install_name_tool -id @rpath/rsa.dylib ${MOPROKIT_DIR}/Libs/rsa.dylib
codesign -f -s "${APPLE_SIGNING_IDENTITY}" ${MOPROKIT_DIR}/Libs/rsa.dylib

print_action "Done! Please re-build your project in Xcode."