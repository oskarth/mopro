#pragma once

#include "../fields/fp_bn254.h.metal"

using namespace metal;

template<typename Fp>
[[kernel]] void bn254_add(
    constant FpBN254& _p [[ buffer(0) ]],
    constant FpBN254& _q [[ buffer(1) ]],
    device FpBN254& result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    FpBN254 q = _q;
    result = p + q;
}

template<typename Fp>
[[kernel]] void bn254_sub(
    constant FpBN254 &_p [[ buffer(0) ]],
    constant FpBN254 &_q [[ buffer(1) ]],
    device FpBN254 &result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    FpBN254 q = _q;
    result = p - q;
}

template<typename Fp>
[[kernel]] void bn254_mul(
    constant FpBN254 &_p [[ buffer(0) ]],
    constant FpBN254 &_q [[ buffer(1) ]],
    device FpBN254 &result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    FpBN254 q = _q;
    result = p * q;
}

template<typename Fp>
[[kernel]] void bn254_pow(
    constant FpBN254 &_p [[ buffer(0) ]],
    constant uint32_t &_a [[ buffer(1) ]],
    device FpBN254 &result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    result = p.pow(_a);
}

template<typename Fp>
[[kernel]] void bn254_neg(
    constant FpBN254 &_p [[ buffer(0) ]],
    constant FpBN254 &_q [[ buffer(1) ]],
    device FpBN254 &result [[ buffer(2) ]]
) {
    FpBN254 p = _p;
    result = p.neg();
}

// // TODO: Implement inverse if needed in the future
// [[kernel]] void bn254_inv(
//     constant FpBN254 &_p [[ buffer(0) ]],
//     constant FpBN254 &_q [[ buffer(1) ]],
//     device FpBN254 &result [[ buffer(2) ]]
// ) {
//     FpBN254 p = _p;
//     FpBN254 inv_p = p.inverse();
//     result = inv_p;
// }
