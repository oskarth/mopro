#!/bin/bash

# Script to build and prepare circuits for mopro.
#
# Does the following:
# - Install npm dependencies and compiles the circuit
# - Run trusted setup
# - Generate arkzkey

# Initialize environment and check prerequisites
initialize_environment() {
    if [ -z "$MOPRO_ROOT" ]; then
        echo "MOPRO_ROOT is not set. Please set it to your local mopro repository."
        exit 1
    fi

    if ! command -v toml &> /dev/null; then
        echo -e "${RED}toml (toml-cli) is not installed. Please install it to continue.${DEFAULT}"
        exit 1
    fi

    if ! command -v arkzkey-util &> /dev/null; then
        echo "Error: arkzkey-util command is not available."
        exit 1
    fi

    if [ "$#" -ne 1 ]; then
        echo -e "\n${RED}Usage: $0 path/to/config.toml${DEFAULT}"
        exit 1
    fi

    source "${MOPRO_ROOT}/scripts/_prelude.sh"
}

# Function to validate TOML syntax and structure
validate_toml() {
    local toml_file="$1"
    if ! command -v toml >/dev/null; then
        echo -e "${RED}'toml' (toml-cli) command not found. Please install it to continue.${DEFAULT}"
        exit 1
    fi

    local error_file=$(mktemp)
    if ! toml get "$toml_file" "build" > /dev/null 2> "$error_file"; then
        local error_message=$(<"$error_file")
        echo -e "${RED}TOML parse error in $toml_file:${DEFAULT}\n$error_message"
        rm "$error_file"
        exit 1
    fi
    rm "$error_file"
}

# Read configuration from TOML file
read_configuration() {
    CONFIG_FILE="$1"
    export BUILD_CONFIG_PATH="$PWD/$CONFIG_FILE"
    print_action "Using build configuration file: $BUILD_CONFIG_PATH"

    validate_toml "$CONFIG_FILE"

    BUILD_MODE=$(read_toml "$CONFIG_FILE" "build.build_mode")
    USE_DYLIB=$(read_toml "$CONFIG_FILE" "dylib.use_dylib")
    DYLIB_NAME=$(read_toml "$CONFIG_FILE" "dylib.name")
    CIRCUIT_DIR=$(read_toml "$CONFIG_FILE" "circuit.dir")
    CIRCUIT_NAME=$(read_toml "$CONFIG_FILE" "circuit.name")
    CIRCUIT_PTAU=$(read_toml "$CONFIG_FILE" "circuit.ptau")

    OUTPUT_DIR="${CIRCUIT_DIR}/target"
}

# Function to read value from TOML file and remove quotes
read_toml() {
    local value=$(toml get "$1" "$2" 2>/dev/null || true)

    if [ -z "$value" ]; then
        echo -e "${RED}Error: Key '$2' not found in $1${DEFAULT}" >&2
        exit 1
    fi

    echo "$value" | tr -d '"'
}

# Compile the circuit
compile_circuit() {
    print_action "Compiling circuit $CIRCUIT_NAME..."
    local circuit_file_path="${CIRCUIT_DIR}/${CIRCUIT_NAME}.circom"

    # Ensure output dir exists
    mkdir -p "$OUTPUT_DIR"

    # Compile the circuit using circom
    circom "$circuit_file_path" --O0 --r1cs --wasm --sym --output "$OUTPUT_DIR"
}

# Trusted setup for the circuit
trusted_setup() {
    print_action "Running trusted setup for $CIRCUIT_NAME..."

    # Change this is if you keep your Powers of Tau files elsewhere
    local ptau_dir="ptau"
    local ptau="${CIRCUIT_PTAU}"
    local ptau_path="${ptau_dir}/powersOfTau28_hez_final_${ptau}.ptau"
    local zkey_output="${OUTPUT_DIR}/${CIRCUIT_NAME}_final.zkey"

    # Ensure the ptau directory exists
    mkdir -p "$ptau_dir"

    # Phase 1 - Perpetual Powers of Tau
    # From https://github.com/iden3/snarkjs

    # Download the Powers of Tau file if it doesn't exist
    if [ ! -f "$ptau_path" ]; then
        echo "Downloading Powers of Tau file..."
        wget -P "$ptau_dir" "https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_${ptau}.ptau"
    else
        echo "File $ptau_path already exists, skipping download."
    fi

    # Phase 2 - Circuit specific setup
    # Toy example, not for production use
    # For a real deployment with Groth16 use a tool like p0tion for phase 2 trusted setup
    # See https://github.com/privacy-scaling-explorations/p0tion

    echo "Generate zkey file for ${CIRCUIT_NAME}..."
    if [ ! -f "$zkey_output" ]; then
        snarkjs groth16 setup "${OUTPUT_DIR}/${CIRCUIT_NAME}.r1cs" "$ptau_path" "${OUTPUT_DIR}/${CIRCUIT_NAME}_0000.zkey"
        snarkjs zkey contribute "${OUTPUT_DIR}/${CIRCUIT_NAME}_0000.zkey" "$zkey_output" \
        --name="Demo contributor" -v -e="0xdeadbeef"
    else
        echo "File $zkey_output already exists, skipping."
    fi

    echo "Trusted setup done, zkey file is in $zkey_output"
}

# Generate arkzkey for the circuit
generate_arkzkey() {
    local ZKEY_PATH="${OUTPUT_DIR}/${CIRCUIT_NAME}_final.zkey"
    local ARKZKEY_PATH="${OUTPUT_DIR}/${CIRCUIT_NAME}_final.arkzkey"

    print_action "Generating arkzkey for $CIRCUIT_NAME..."

    echo "Generate arkzkey file for ${CIRCUIT_NAME}..."
    if [ ! -f "$ARKZKEY_PATH" ]; then
        arkzkey-util "${ZKEY_PATH}"
    else
        echo "File $ZKEY_PATH already exists, skipping."
    fi

    echo "Arkzkey generation done, arkzkey file is in $ARKZKEY_PATH"
}


# Main function to orchestrate the script
main() {
    initialize_environment "$@"
    read_configuration "$1"
    compile_circuit
    trusted_setup
    generate_arkzkey
    print_action "Circuit and its artifacts built successfully."
}

main "$@"