use mopro_core::middleware::circom;
use mopro_core::MoproError;

use num_bigint::BigInt;

use std::collections::HashMap;
use std::path::Path;
use std::sync::RwLock;

#[derive(Debug)]
pub enum FFIError {
    MoproError(mopro_core::MoproError),
    SerializationError(String),
}

#[derive(Debug, Clone)]
pub struct GenerateProofResult {
    pub proof: Vec<u8>,
    pub inputs: Vec<u8>,
}

// NOTE: Make UniFFI and Rust happy, can maybe do some renaming here
#[allow(non_snake_case)]
#[derive(Debug, Clone)]
pub struct SetupResult {
    pub provingKey: Vec<u8>,
}

//     pub inputs: Vec<u8>,

impl From<mopro_core::MoproError> for FFIError {
    fn from(error: mopro_core::MoproError) -> Self {
        FFIError::MoproError(error)
    }
}

pub struct MoproCircom {
    state: RwLock<circom::CircomState>,
}

impl Default for MoproCircom {
    fn default() -> Self {
        Self::new()
    }
}

fn initialize(path: String) {
    circom::initialize(Path::new(path.as_str()));
}

// TODO: Basic generate_proof thing here
fn generate_proof2(inputs: HashMap<String, Vec<i32>>) -> Result<(), MoproError> {
    // Convert inputs to BigInt
    let bigint_inputs = inputs
        .into_iter()
        .map(|(k, v)| (k, v.into_iter().map(|i| BigInt::from(i)).collect()))
        .collect();

    let _foo = circom::generate_proof2(bigint_inputs)?;

    Ok(())
}

// TODO: Use setup, prove and verify functions from mopro_core

// TODO: Use FFIError::SerializationError instead
impl MoproCircom {
    pub fn new() -> Self {
        Self {
            state: RwLock::new(circom::CircomState::new()),
        }
    }

    pub fn setup(&self, wasm_path: String, r1cs_path: String) -> Result<SetupResult, MoproError> {
        let mut state_guard = self.state.write().unwrap();
        let pk = state_guard.setup(wasm_path.as_str(), r1cs_path.as_str())?;
        Ok(SetupResult {
            provingKey: circom::serialization::serialize_proving_key(&pk),
        })
    }

    //             inputs: circom::serialization::serialize_inputs(&inputs),

    pub fn generate_proof(
        &self,
        inputs: HashMap<String, Vec<i32>>,
    ) -> Result<GenerateProofResult, MoproError> {
        let mut state_guard = self.state.write().unwrap();

        // Convert inputs to BigInt
        let bigint_inputs = inputs
            .into_iter()
            .map(|(k, v)| (k, v.into_iter().map(|i| BigInt::from(i)).collect()))
            .collect();

        let (proof, inputs) = state_guard.generate_proof(bigint_inputs)?;

        Ok(GenerateProofResult {
            proof: circom::serialization::serialize_proof(&proof),
            inputs: circom::serialization::serialize_inputs(&inputs),
        })
    }

    pub fn verify_proof(&self, proof: Vec<u8>, public_input: Vec<u8>) -> Result<bool, MoproError> {
        let state_guard = self.state.read().unwrap();
        let deserialized_proof = circom::serialization::deserialize_proof(proof);
        let deserialized_public_input = circom::serialization::deserialize_inputs(public_input);
        let is_valid = state_guard.verify_proof(deserialized_proof, deserialized_public_input)?;
        Ok(is_valid)
    }
}

fn add(a: u32, b: u32) -> u32 {
    a + b
}

fn hello() -> String {
    "Hello World from Rust".to_string()
}

// XXX: Do we need this?
pub fn init_circom_state() -> Result<(), MoproError> {
    //let mut circom_state = circom::CircomState::new();
    Ok(())
}

// TODO: Remove me
// UniFFI expects String type
// See https://mozilla.github.io/uniffi-rs/udl/builtin_types.html
// fn run_example(wasm_path: String, r1cs_path: String) -> Result<(), MoproError> {
//     circom::run_example(wasm_path.as_str(), r1cs_path.as_str())
// }

uniffi::include_scaffolding!("mopro");

#[cfg(test)]
mod tests {
    use super::*;

    fn bytes_to_circuit_inputs(input_vec: &Vec<u8>) -> HashMap<String, Vec<i32>> {
        let bits = circom::utils::bytes_to_bits(&input_vec);
        let converted_vec: Vec<i32> = bits.into_iter().map(|bit| bit as i32).collect();
        let mut inputs = HashMap::new();
        inputs.insert("in".to_string(), converted_vec);
        inputs
    }

    #[test]
    fn add_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }

    #[test]
    fn test_end_to_end() -> Result<(), MoproError> {
        // Paths to your wasm and r1cs files
        let wasm_path = "./../mopro-core/examples/circom/target/multiplier2_js/multiplier2.wasm";
        let r1cs_path = "./../mopro-core/examples/circom/target/multiplier2.r1cs";

        // Create a new MoproCircom instance
        let mopro_circom = MoproCircom::new();

        // Step 1: Setup
        let setup_result = mopro_circom.setup(wasm_path.to_string(), r1cs_path.to_string())?;
        assert!(setup_result.provingKey.len() > 0);

        let mut inputs = HashMap::new();
        inputs.insert("a".to_string(), vec![3_i32; 1]);
        inputs.insert("b".to_string(), vec![5_i32; 1]);

        // Step 2: Generate Proof
        let generate_proof_result = mopro_circom.generate_proof(inputs)?;
        let serialized_proof = generate_proof_result.proof;
        let serialized_inputs = generate_proof_result.inputs;

        assert!(serialized_proof.len() > 0);

        // Step 3: Verify Proof
        // TODO: This should also check inputs, make sure it does
        let is_valid = mopro_circom.verify_proof(serialized_proof, serialized_inputs)?;
        assert!(is_valid);

        Ok(())
    }

    #[test]
    fn test_end_to_end_keccak() -> Result<(), MoproError> {
        // Paths to your wasm and r1cs files
        let wasm_path =
            "./../mopro-core/examples/circom/keccak256/target/keccak256_256_test_js/keccak256_256_test.wasm";
        let r1cs_path = "./../mopro-core/examples/circom/keccak256/target/keccak256_256_test.r1cs";

        // Create a new MoproCircom instance
        let mopro_circom = MoproCircom::new();

        // Step 1: Setup
        let setup_result = mopro_circom.setup(wasm_path.to_string(), r1cs_path.to_string())?;
        assert!(setup_result.provingKey.len() > 0);

        // Prepare inputs
        let input_vec = vec![
            116, 101, 115, 116, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0,
        ];

        let inputs = bytes_to_circuit_inputs(&input_vec);

        // Step 2: Generate Proof
        let generate_proof_result = mopro_circom.generate_proof(inputs)?;
        let serialized_proof = generate_proof_result.proof;
        let serialized_inputs = generate_proof_result.inputs;

        assert!(serialized_proof.len() > 0);

        // Step 3: Verify Proof
        // TODO: This should also check inputs, make sure it does
        let is_valid = mopro_circom.verify_proof(serialized_proof, serialized_inputs)?;
        assert!(is_valid);

        Ok(())
    }
}
