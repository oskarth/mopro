use rust_witness::witness;
#[cfg(not(feature = "halo2"))]
use {mopro_core::middleware::circom::CircomState, num_bigint::BigInt, std::collections::HashMap};

#[cfg(not(feature = "halo2"))]
witness!(multiplier2);

#[cfg(not(feature = "halo2"))]
fn main() {
    let zkey_path = "./examples/circom/multiplier2/target/multiplier2_final.zkey";

    // Instantiate CircomState
    let mut circom_state = CircomState::new();

    // Setup
    let setup_res = circom_state.initialize(zkey_path, multiplier2_witness);
    assert!(setup_res.is_ok());

    let _serialized_pk = setup_res.unwrap();

    // Deserialize the proving key and inputs if necessary

    // Prepare inputs
    let mut inputs = HashMap::new();
    inputs.insert("a".to_string(), vec![BigInt::from(3)]);
    inputs.insert("b".to_string(), vec![BigInt::from(5)]);

    // Proof generation
    let generate_proof_res = circom_state.generate_proof(inputs);

    // Check and print the error if there is one
    if let Err(e) = &generate_proof_res {
        println!("Error: {:?}", e);
    }

    assert!(generate_proof_res.is_ok());

    let (serialized_proof, serialized_inputs) = generate_proof_res.unwrap();

    // Proof verification
    let verify_res = circom_state.verify_proof(serialized_proof, serialized_inputs);
    assert!(verify_res.is_ok());
    assert!(verify_res.unwrap()); // Verifying that the proof was indeed verified
}

#[cfg(feature = "halo2")]
fn main() {
    println!("This example is only for Circom proving system. Currently, Halo2 proving system is enabled. Please disable the Halo2 feature in the Cargo.toml file.");
}
