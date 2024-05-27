#pragma once

#include "../fields/fp_bn254.h.metal"

using namespace metal;

[[kernel]] void test_bn254_add(
    constant FpBN254& _p [[ buffer(0) ]],
    constant FpBN254& _q [[ buffer(1) ]],
    device FpBN254& result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    FpBN254 q = _q;
    result = p + q;
}

[[kernel]] void test_bn254_sub(
    constant FpBN254 &_p [[ buffer(0) ]],
    constant FpBN254 &_q [[ buffer(1) ]],
    device FpBN254 &result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    FpBN254 q = _q;
    result = p - q;
}

[[kernel]] void test_bn254_mul(
    constant FpBN254 &_p [[ buffer(0) ]],
    constant FpBN254 &_q [[ buffer(1) ]],
    device FpBN254 &result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    FpBN254 q = _q;
    result = p * q;
    // out[0] = static_cast<uint32_t>(result);
}

[[kernel]] void test_bn254_inversion(
    constant FpBN254 &_p [[ buffer(0) ]],
    constant FpBN254 &_q [[ buffer(1) ]],
    device FpBN254 &result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    FpBN254 inv_p = p.inverse();
    result = inv_p;
    // FpBN254 result = a * inv_p;
    // out[0] = static_cast<uint32_t>(result);
}

[[kernel]] void test_bn254_neg(
    constant FpBN254 &_p [[ buffer(0) ]],
    constant FpBN254 &_q [[ buffer(1) ]],
    device FpBN254 &result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    result = p.neg();
    // out[0] = static_cast<uint32_t>(result);
}

[[kernel]] void test_bn254_mont_reduction(
    constant FpBN254 &_p [[ buffer(0) ]],
    constant FpBN254 &_q [[ buffer(1) ]],
    device FpBN254 &result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    FpBN254 mont_p = p.to_montgomery();
    result = mont_p;
    // FpBN254 from_mont_p = mont_p * FpBN254::one();
    // out[0] = static_cast<uint32_t>(from_mont_p);
}

[[kernel]] void test_bn254_exp(
    constant FpBN254 &_p [[ buffer(0) ]],
    constant uint32_t &_a [[ buffer(1) ]],
    device FpBN254 &result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    result = p.pow(_a);
    // out[0] = static_cast<uint32_t>(result);
}

[[kernel]] void test_bn254_eq(
    constant FpBN254 &_p [[ buffer(0) ]],
    constant FpBN254 &_q [[ buffer(1) ]],
    device bool &result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    FpBN254 q = _q;
    result = (p == q);
}

[[kernel]] void test_bn254_ineq(
    constant FpBN254 &_p [[ buffer(0) ]],
    constant FpBN254 &_q [[ buffer(1) ]],
    device bool &result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    FpBN254 q = _q;
    result = (p != q); // Should be true
}
