#![allow(unused_variables)]

#[cfg(feature = "halo2")]
pub(crate) use common::*;

/// Module that contains all the shared adapter functionality implemented for the Halo2 adapter.
/// As the adapter is only used when the `halo2` feature is enabled,
/// we make the compiler avoid the shared functions of module when the feature is not enabled.
#[cfg(feature = "halo2")]
mod common {
    use std::collections::HashMap;

    use mopro_core::middleware::halo2;
    use mopro_core::middleware::halo2::deserialize_circuit_inputs;
    use mopro_core::MoproError;

    use crate::GenerateProofResult;

    pub fn generate_proof_static(
        circuit_inputs: HashMap<String, Vec<String>>,
    ) -> Result<GenerateProofResult, MoproError> {
        let circuit_inputs = deserialize_circuit_inputs(circuit_inputs);

        let (proof, inputs) = halo2::generate_halo2_proof(circuit_inputs).unwrap();

        let serialized_proof =
            bincode::serialize(&proof).map_err(|e| MoproError::Halo2Error(e.to_string()))?;
        let serialized_inputs =
            bincode::serialize(&inputs).expect("Serialization of Inputs failed");

        Ok(GenerateProofResult {
            proof: serialized_proof,
            inputs: serialized_inputs,
        })
    }

    pub fn verify_proof_static(proof: Vec<u8>, public_inputs: Vec<u8>) -> Result<bool, MoproError> {
        let deserialized_proof: halo2::SerializableProof =
            bincode::deserialize(&proof).map_err(|e| MoproError::Halo2Error(e.to_string()))?;
        let deserialized_inputs: halo2::SerializablePublicInputs =
            bincode::deserialize(&public_inputs)
                .map_err(|e| MoproError::Halo2Error(e.to_string()))?;
        let is_valid = halo2::verify_halo2_proof(deserialized_proof, deserialized_inputs).unwrap();
        Ok(is_valid)
    }

    pub fn initialize_mopro() -> Result<(), MoproError> {
        panic!("Mopro Halo2 does not implement initialization yet.");
    }

    pub fn initialize_mopro_dylib(dylib_path: String) -> Result<(), MoproError> {
        panic!("Mopro Halo2 does not implement dylib initialization yet.");
    }

    #[cfg(test)]
    mod test {
        use crate::adapter::{generate_proof_static, verify_proof_static};
        use halo2curves::bn256::Fr;
        use mopro_core::middleware::halo2::SerializablePublicInputs;
        use mopro_core::MoproError;
        use std::collections::HashMap;

        #[test]
        fn test_end_to_end() -> Result<(), MoproError> {
            // We by default compile the Fibonacci Halo2 Circuit
            // TODO - For the future we should consider a stateful circuit to change the keys on the fly.

            let mut inputs = HashMap::new();
            let out = 55u64;
            inputs.insert("out".to_string(), vec![out.to_string()]);

            let expected_output = vec![Fr::from(1), Fr::from(1), Fr::from(out)];
            let expected_output_bytes =
                bincode::serialize(&SerializablePublicInputs(expected_output))
                    .expect("Serialization of Output Expected bytes failed");

            // Step 2: Generate Proof
            let generate_proof_result = generate_proof_static(inputs)?;
            let serialized_proof = generate_proof_result.proof;
            let serialized_inputs = generate_proof_result.inputs;

            assert!(serialized_proof.len() > 0);
            assert_eq!(serialized_inputs, expected_output_bytes);

            // Step 3: Verify Proof
            let is_valid =
                verify_proof_static(serialized_proof.clone(), serialized_inputs.clone())?;
            assert!(is_valid);

            Ok(())
        }
    }
}
