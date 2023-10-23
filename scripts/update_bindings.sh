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
if [[ "$1" == "simulator" ]]; then
    DEVICE_TYPE="simulator"
    ARCHITECTURE="aarch64-apple-ios-sim"
elif [[ "$1" == "device" ]]; then
    DEVICE_TYPE="device"
    ARCHITECTURE="aarch64-apple-ios"
else
    echo -e "${RED}Error: Please specify either 'simulator' or 'device' as the first argument.${DEFAULT}"
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

print_action "Updating mopro-ffi bindings and library (${BUILD_MODE} ${DEVICE_TYPE})..."

PROJECT_DIR=$(pwd)
TARGET_DIR=${PROJECT_DIR}/target
MOPROKIT_DIR=${PROJECT_DIR}/mopro-ios/MoproKit

# For dylib stuff
mkdir -p ${TARGET_DIR}/${ARCHITECTURE}/${BUILD_MODE}

export TARGET_DIR
export BUILD_MODE

print_action "Generating Swift bindings..."
uniffi-bindgen generate ${PROJECT_DIR}/mopro-ffi/src/mopro.udl --language swift --out-dir ${TARGET_DIR}/SwiftBindings

# XXX
#print_action "Building universal libraries with cargo lipo..."
#(cd ${PROJECT_DIR}/mopro-ffi && cargo lipo --release --targets aarch64-apple-ios,aarch64-apple-darwin)

print_action "Building mopro-ffi static library (${BUILD_MODE})..."
(cd ${PROJECT_DIR}/mopro-ffi && make ${BUILD_MODE})

# Print appropriate message based on device type
if [[ "$DEVICE_TYPE" == "simulator" ]]; then
    print_action "Using ${ARCHITECTURE} libmopro_ffi.a (${LIB_DIR}) static library..."
    print_warning "This only works on iOS simulator (ARM64)"
elif [[ "$DEVICE_TYPE" == "device" ]]; then
    print_action "Using ${ARCHITECTURE} libmopro_ffi.a (${LIB_DIR}) static library..."
    print_warning "This only works on iOS devices (ARM64)"
fi

#cp ${PROJECT_DIR}/mopro-ffi/target/${ARCHITECTURE}/${LIB_DIR}/libmopro_ffi.a ${TARGET_DIR}/
# Copy dynamic lib
cp ${PROJECT_DIR}/mopro-ffi/target/${ARCHITECTURE}/${LIB_DIR}/libmopro_ffi.dylib ${TARGET_DIR}/

print_action "Copying Swift bindings and static library to MoproKit..."
cp ${TARGET_DIR}/SwiftBindings/moproFFI.h ${MOPROKIT_DIR}/Include/
cp ${TARGET_DIR}/SwiftBindings/mopro.swift ${MOPROKIT_DIR}/Bindings/
cp ${TARGET_DIR}/SwiftBindings/moproFFI.modulemap ${MOPROKIT_DIR}/Resources/


#cp ${TARGET_DIR}/libmopro_ffi.a ${MOPROKIT_DIR}/Libs/
cp ${TARGET_DIR}/libmopro_ffi.dylib ${MOPROKIT_DIR}/Libs/
cp ${TARGET_DIR}/keccak256.dylib ${MOPROKIT_DIR}/Libs/

print_action "Done! Please re-build your project in Xcode."

# Fix dynamic lib install paths
install_name_tool -id @rpath/libmopro_ffi.dylib ${MOPROKIT_DIR}/Libs/libmopro_ffi.dylib

# XXX: Actually a bit complicated, because we want the iOS compiled one
# But we can't compile this in build.rs with forked wasmer, so instead we do this ad-hoc
# The iOS compiled one should be in right target dir, and then we only install iOS one
#install_name_tool -id @rpath/keccak256.dylib ${MOPROKIT_DIR}/Libs/keccak256.dylib
# Instead we do ad hoc
#cp mopro-ios/MoproKit/Libs/keccak256_real.dylib mopro-ios/MoproKit/Libs/keccak256.dylib           
#install_name_tool -id @rpath/keccak256.dylib mopro-ios/MoproKit/Libs/keccak256.dylib               
#codesign -f -s "$#{APPLE_SIGNING_IDENTITY}" mopro-ios/MoproKit/Libs/keccak256.dylib

# where _real is compiled for iOS (before wasmer memory fix fork)

# NOTE: Need to set APPLE_SIGNING_IDENTITY environment variable (Keychain Access)
codesign -f -s "${APPLE_SIGNING_IDENTITY}" mopro-ios/MoproKit/Libs/libmopro_ffi.dylib