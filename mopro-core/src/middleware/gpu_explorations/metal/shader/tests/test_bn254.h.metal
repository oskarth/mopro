#pragma once

#include "../fields/fp_bn254.h.metal"

using namespace metal;

[[kernel]] void test_bn254_add(device uint* out [[buffer(0)]]) {
    FpBN254 a = FpBN254(3);
    FpBN254 b = FpBN254(5);
    FpBN254 add_result = a + b; // Should be 3 + 5 = 8
    out[0] = static_cast<uint32_t>(add_result); // Expect 8
}

[[kernel]] void test_bn254_sub(device uint* out [[buffer(0)]]) {
    FpBN254 a = FpBN254(7);
    FpBN254 b = FpBN254(3);
    FpBN254 sub_result = a - b; // Should be 7 - 3 = 4
    out[0] = static_cast<uint32_t>(sub_result); // Expect 4
}

[[kernel]] void test_bn254_mul(device uint* out [[buffer(0)]]) {
    FpBN254 a = FpBN254(5);
    FpBN254 b = FpBN254(11);
    FpBN254 mul_result = a * b; // Should be 5 * 11 = 55
    out[0] = static_cast<uint32_t>(mul_result); // Expect 55
}

[[kernel]] void test_bn254_inversion(device uint* out [[buffer(0)]]) {
    FpBN254 a = FpBN254(3);
    FpBN254 inv_a = a.inverse();
    FpBN254 inv_test = a * inv_a; // Should be 1
    out[0] = static_cast<uint32_t>(inv_test); // Expect 1
}

[[kernel]] void test_bn254_neg(device uint* out [[buffer(0)]]) {
    FpBN254 a = FpBN254(3);
    FpBN254 neg_result = a.neg(); // Should be 0 - 0 = 0
    out[0] = static_cast<uint32_t>(neg_result); // Expect 0
}

[[kernel]] void test_bn254_mont_reduction(device uint* out [[buffer(0)]]) {
    FpBN254 a = FpBN254(3);
    FpBN254 mont_a = a.to_montgomery();
    FpBN254 from_mont_a = mont_a * FpBN254::one(); // Should be 3 in Montgomery form, then back to normal
    out[0] = static_cast<uint32_t>(from_mont_a); // Expect 3
}

[[kernel]] void test_bn254_exp(device uint* out [[buffer(0)]]) {
    FpBN254 a = FpBN254(5);
    FpBN254 exp_result = a.pow(3); // Should be 5^3 = 125
    out[0] = static_cast<uint32_t>(exp_result); // Expect 125
}

[[kernel]] void test_bn254_eq(device uint* out [[buffer(0)]]) {
    FpBN254 a = FpBN254(3);
    FpBN254 b = FpBN254(3);
    bool eq_test = (a == b); // Should be true
    out[0] = eq_test ? 1 : 0; // Expect 1
}

[[kernel]] void test_bn254_ineq(device uint* out [[buffer(0)]]) {
    FpBN254 a = FpBN254(3);
    FpBN254 b = FpBN254(5);
    bool neq_test = (a != b); // Should be true
    out[0] = neq_test ? 1 : 0; // Expect 1
}
