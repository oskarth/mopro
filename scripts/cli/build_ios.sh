#!/bin/bash

# Script for initializing and updating an iOS (simplified) project with Rust bindings.

# Prelude
#----------------------------------------------------------------------------
initialize_environment() {
    if [ -z "$MOPRO_ROOT" ]; then
        echo "MOPRO_ROOT is not set. Please set it to your local mopro repository."
        exit 1
    fi

    if ! command -v toml &> /dev/null; then
        echo -e "${RED}toml (toml-cli) is not installed. Please install it to continue.${DEFAULT}"
        exit 1
    fi

    if [ "$#" -ne 1 ]; then
        echo -e "\n${RED}Usage: $0 path/to/config.toml${DEFAULT}"
        exit 1
    fi

    source "${MOPRO_ROOT}/scripts/_prelude.sh"
}

read_configuration() {
    CONFIG_FILE="$1"
    export BUILD_CONFIG_PATH="$PROJECT_DIR/$CONFIG_FILE"
    print_action "Using build configuration file: $BUILD_CONFIG_PATH"

    DEVICE_TYPE=$(read_toml "$CONFIG_FILE" "build.ios_device_type")
    BUILD_MODE=$(read_toml "$CONFIG_FILE" "build.build_mode")
    USE_DYLIB=$(read_toml "$CONFIG_FILE" "dylib.use_dylib")
    DYLIB_NAME=$(read_toml "$CONFIG_FILE" "dylib.name")
}

# Function to read value from TOML file and remove quotes
read_toml() {
    toml get "$1" "$2" | tr -d '"'
}

# Determine the architecture based on device type
determine_architecture() {
    case $DEVICE_TYPE in
        "x86_64")
            ARCHITECTURE="x86_64-apple-ios"
            ;;
        "simulator")
            ARCHITECTURE="aarch64-apple-ios-sim"
            ;;
        "device")
            ARCHITECTURE="aarch64-apple-ios"
            ;;
        *)
            echo -e "\n${RED}Error: Invalid device type specified in config: $DEVICE_TYPE${DEFAULT}"
            exit 1
            ;;
    esac
}

# Determine the library directory based on build mode
determine_build_directory() {
    case $BUILD_MODE in
        "debug")
            LIB_DIR="debug"
            ;;
        "release")
            LIB_DIR="release"
            ;;
        *)
            echo -e "\n${RED}Error: Invalid build mode specified in config: $BUILD_MODE${DEFAULT}"
            exit 1
            ;;
    esac
}

# Build process
#----------------------------------------------------------------------------

# Build process for mopro_core
build_mopro_core() {
    cd "${MOPRO_ROOT}/mopro-core" || exit
    print_action "Building mopro-core ($BUILD_MODE)..."
    if [[ "$BUILD_MODE" == "release" ]]; then
        env BUILD_CONFIG_PATH="$BUILD_CONFIG_PATH" cargo build --target "$ARCHITECTURE" --release
    else
        env BUILD_CONFIG_PATH="$BUILD_CONFIG_PATH" cargo build --target "$ARCHITECTURE"
    fi
}

build_mopro_ffi_static() {
    cd "${MOPRO_ROOT}/mopro-ffi" || exit
    print_action "Building mopro-ffi as a static library ($BUILD_MODE)..."
    if [[ "$BUILD_MODE" == "release" ]]; then
        cargo build --release --target "$ARCHITECTURE"
    else
        cargo build --target "$ARCHITECTURE"
    fi

    # Ensure the target directory exists
    mkdir -p "${TARGET_DIR}/${ARCHITECTURE}/${LIB_DIR}"

    # Copy the static library to the target directory
    print_action "Copying static library to target directory..."
    cp "${MOPRO_ROOT}/target/${ARCHITECTURE}/${LIB_DIR}/libmopro_ffi.a" \
        "${TARGET_DIR}/${ARCHITECTURE}/${LIB_DIR}/libmopro_ffi.a"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to copy static library.${DEFAULT}"
        exit 1
    fi
}

build_mopro_ffi_with_dylib_circuit() {
    cd "${MOPRO_ROOT}/mopro-ffi" || exit
    print_action "Building mopro-ffi with dylib circuit ($BUILD_MODE)..."

    if [[ "$BUILD_MODE" == "release" ]]; then
        cargo build --release --target "$ARCHITECTURE" --features dylib
    else
        cargo build --target "$ARCHITECTURE" --features dylib
    fi

    # Ensure the target directory exists
    mkdir -p "${TARGET_DIR}/${ARCHITECTURE}/${LIB_DIR}"

    # Copy the static library to the target directory
    print_action "Copying static library to target directory..."
    cp "${MOPRO_ROOT}/target/${ARCHITECTURE}/${LIB_DIR}/libmopro_ffi.a" \
        "${TARGET_DIR}/${ARCHITECTURE}/${LIB_DIR}/libmopro_ffi.a"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to copy static library.${DEFAULT}"
        exit 1
    fi

    # NOTE: Doesn't seem like we need this
    # # Copy the dynamic library to the target directory
    # print_action "Copying dynamic library to target directory..."
    # cp "${MOPRO_ROOT}/target/${ARCHITECTURE}/${LIB_DIR}/libmopro_ffi.dylib" \
    #     "${TARGET_DIR}/${ARCHITECTURE}/${LIB_DIR}/libmopro_ffi.dylib"
    # if [ $? -ne 0 ]; then
    #     echo -e "${RED}Failed to copy dynamic library.${DEFAULT}"
    #     exit 1
    # fi

    print_action "Copying dylib circuit to target directory..."
    cp "${MOPRO_ROOT}/mopro-core/target/${ARCHITECTURE}/${LIB_DIR}/${DYLIB_NAME}.dylib" \
        "${TARGET_DIR}/${ARCHITECTURE}/${LIB_DIR}/${DYLIB_NAME}.dylib"
}

generate_swift_bindings() {
    print_action "Generating Swift bindings..."
    uniffi-bindgen generate "${MOPRO_ROOT}/mopro-ffi/src/mopro.udl" --language swift --out-dir "${TARGET_DIR}/SwiftBindings"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to generate Swift bindings.${DEFAULT}"
        exit 1
    fi

    # Rename modulemap to module.modulemap
    mv "${TARGET_DIR}/SwiftBindings/moproFFI.modulemap" "${TARGET_DIR}/SwiftBindings/module.modulemap"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to rename modulemap to module.modulemap.${DEFAULT}"
        exit 1
    fi

    # Copy the mopro.swift file to the Bindings directory
    cp "${TARGET_DIR}/SwiftBindings/mopro.swift" "${IOS_APP_DIR}/Bindings/mopro.swift"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to copy mopro.swift to Bindings directory.${DEFAULT}"
        exit 1
    fi
}

create_xcframework_mopro() {
    print_action "Cleaning up existing MoproBindings XCFramework..."
    MOPRO_XCFRAMEWORK_PATH="${IOS_APP_DIR}/Frameworks/MoproBindings.xcframework"

    # Clean up any existing MoproBindings XCFramework
    if [ -d "$MOPRO_XCFRAMEWORK_PATH" ]; then
        rm -rf "$MOPRO_XCFRAMEWORK_PATH"
    fi

    print_action "Creating XCFramework for MoproBindings... (${ARCHITECTURE})"
    xcodebuild -create-xcframework \
        -library "${TARGET_DIR}/${ARCHITECTURE}/release/libmopro_ffi.a" \
        -headers "${TARGET_DIR}/SwiftBindings" \
        -output "$MOPRO_XCFRAMEWORK_PATH"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create MoproBindings XCFramework.${DEFAULT}"
        exit 1
    fi

    print_action "MoproBindings XCFramework created successfully"
}

# NOTE: Earlier in the build process we converted .wasm to .dylib.
# This is done to comply with Apple's requirements for iOS apps.
# This currently only works on real devices.
create_xcframework_circuit() {
    print_action "Cleaning up existing CircuitBindings Framework..."
    CIRCUIT_FRAMEWORK_PATH="${IOS_APP_DIR}/Frameworks/CircuitBindings.framework"

    print_action "Creating Framework for CircuitBindings dylib... (${ARCHITECTURE})"
    mv "${TARGET_DIR}/${ARCHITECTURE}/release/${DYLIB_NAME}.dylib" $CIRCUIT_FRAMEWORK_PATH/

    print_action "CircuitBindings XCFramework created successfully"
}

update_cocoapods() {
    cd ${IOS_APP_DIR}
    pod install
}

print_dylib_instructions() {
    print_action "Instructions for how to embed the dylib framework into your iOS application:"
    echo "
- Go to ExampleApp -> Build Phases -> Embed Framework and add it there
- You may have to add the framework manually for it to show up
- The dylib should not be linked under Link Binary with Libraries
- Make sure code signing is on
- The dylib should be available inside your app bundle under the Frameworks folder\n"
}

# Main
#----------------------------------------------------------------------------
main() {
    PROJECT_DIR=$(pwd)
    TARGET_DIR=${PROJECT_DIR}/target
    IOS_APP_DIR=${PROJECT_DIR}/ios/ExampleApp

    initialize_environment "$@"
    read_configuration "$1"
    determine_architecture
    determine_build_directory

    if [[ "$USE_DYLIB" == true ]]; then
        build_mopro_ffi_with_dylib_circuit
    else
        build_mopro_ffi_static
    fi

    generate_swift_bindings
    create_xcframework_mopro

    if [[ "$USE_DYLIB" == true ]]; then
        create_xcframework_circuit
        print_dylib_instructions
    fi

    update_cocoapods

    print_action "Done! Please re-build your project in Xcode."
    print_action "Run \`open ios/ExampleApp/ExampleApp.xcworkspace\` to do so."
}

main "$@"
