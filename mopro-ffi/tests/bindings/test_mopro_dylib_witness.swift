import mopro

let dylibPath = "./../../../../mopro-core/target/debug/keccak256.dylib"

// Helper function to convert bytes to bits
func bytesToBits(bytes: [UInt8]) -> [Int32] {
    var bits = [Int32]()
    for byte in bytes {
        for j in 0..<8 {
            let bit = (byte >> j) & 1
            bits.append(Int32(bit))
        }
    }
    return bits
}

do {
    // Initialize the library
    try initialize(path: dylibPath)

    // Prepare inputs
    let inputVec: [UInt8] = [
        116, 101, 115, 116, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0,
]
    let bits = bytesToBits(bytes: inputVec)
    var inputs = [String: [Int32]]()
    inputs["in"] = bits

    // Generate Proof
    try generateProof2(circuitInputs: inputs)

    print("Test passed")

} catch let error as MoproError {
    print("MoproError: \(error)")
} catch {
    print("Unexpected error: \(error)")
}