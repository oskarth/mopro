#pragma once

#include "fp_bls12381.h.metal"
#include "ec_point.h.metal"
#include "../tests/test_bls12381.h.metal"

namespace {
    typedef ECPoint<FpBLS12381, 0> BLS12381;
    typedef UnsignedInteger<12> u384;
}

template [[ host_name("bls12381_add") ]]
[[kernel]] void add<BLS12381, FpBLS12381>(
    constant FpBLS12381*,
    constant FpBLS12381*,
    device FpBLS12381*
);

template [[ host_name("fp_bls12381_add") ]]
[[kernel]] void add_fp<FpBLS12381>(
    constant FpBLS12381&,
    constant FpBLS12381&,
    device FpBLS12381&
);

template [[ host_name("fp_bls12381_sub") ]]
[[kernel]] void sub_fp<FpBLS12381>(
    constant FpBLS12381&,
    constant FpBLS12381&,
    device FpBLS12381&
);

template [[ host_name("fp_bls12381_mul") ]]
[[kernel]] void mul_fp<FpBLS12381>(
    constant FpBLS12381&,
    constant FpBLS12381&,
    device FpBLS12381&
);

template [[ host_name("fp_bls12381_pow") ]]
[[kernel]] void pow_fp<FpBLS12381>(
    constant FpBLS12381&,
    constant uint32_t&,
    device FpBLS12381&
);
