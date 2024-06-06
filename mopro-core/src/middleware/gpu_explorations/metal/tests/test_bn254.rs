#[cfg(all(test))]
mod tests {
    use crate::middleware::gpu_explorations::metal::abstraction::state::MetalState;
    use ark_bn254::{Fq, Fr as ScalarField, G1Affine as GAffine, G1Projective as G};
    use ark_ec::AffineRepr;
    use ark_ff::{Field, PrimeField, biginteger::BigInteger256};

    use metal::MTLSize;
    use proptest::prelude::*;

    pub type Point = GAffine;
    pub type Scalar = <ScalarField as PrimeField>::BigInt;

    // pub type F = BN254PrimeField;
    // pub type FE = FieldElement<F>;
    // pub type U = U256; // F::BaseType

    mod unsigned_int_tests {
        use super::*;

        enum BigOrSmallInt {
            Big(BigInteger256),
            Small(usize),
        }

        fn execute_kernel(name: &str, params: (BigInteger256, BigOrSmallInt)) -> U {
            let state = MetalState::new(None).unwrap();
            let pipeline = state.setup_pipeline(name).unwrap();

            let (a, b) = params;

            let a = a.to_u32_limbs();

            let result_buffer = state.alloc_buffer::<U>(1);

            let (command_buffer, command_encoder) = match b {
                BigOrSmallInt::Big(b) => {
                    let b = b.to_u32_limbs();
                    let a_buffer = state.alloc_buffer_data(&a);
                    let b_buffer = state.alloc_buffer_data(&b);
                    state.setup_command(
                        &pipeline,
                        Some(&[(0, &a_buffer), (1, &b_buffer), (2, &result_buffer)]),
                    )
                }
                BigOrSmallInt::Small(b) => {
                    let a_buffer = state.alloc_buffer_data(&a);
                    let b_buffer = state.alloc_buffer_data(&[b]);
                    state.setup_command(
                        &pipeline,
                        Some(&[(0, &a_buffer), (1, &b_buffer), (2, &result_buffer)]),
                    )
                }
            };

            let threadgroup_size = MTLSize::new(1, 1, 1);
            let threadgroup_count = MTLSize::new(1, 1, 1);

            command_encoder.dispatch_thread_groups(threadgroup_count, threadgroup_size);
            command_encoder.end_encoding();

            command_buffer.commit();
            command_buffer.wait_until_completed();

            let limbs = MetalState::retrieve_contents::<u32>(&result_buffer);
            U::from_u32_limbs(&limbs)
        }

        prop_compose! {
            fn rand_u()(n in any::<u128>()) -> U { U::from_u128(n) }
        }

        use ark_ff::{BigInt, BigInteger};
        use lambdaworks_math::unsigned_integer::traits::U32Limbs;
        use BigOrSmallInt::{Big, Small};

        proptest! {
            #[test]
            fn add(a in rand_u(), b in rand_u()) {
                objc::rc::autoreleasepool(|| {
                    let result = execute_kernel("test_uint_add", (a, Big(b)));
                    prop_assert_eq!(result, a + b);
                    Ok(())
                }).unwrap();
            }

            #[test]
            fn sub(a in rand_u(), b in rand_u()) {
                objc::rc::autoreleasepool(|| {
                    let a = std::cmp::max(a, b);
                    let b = std::cmp::min(a, b);

                    let result = execute_kernel("test_uint_sub", (a, Big(b)));
                    prop_assert_eq!(result, a - b);
                    Ok(())
                }).unwrap();
            }

            #[test]
            fn prod(a in rand_u(), b in rand_u()) {
                objc::rc::autoreleasepool(|| {
                    let result = execute_kernel("test_uint_prod", (a, Big(b)));
                    prop_assert_eq!(result, a * b);
                    Ok(())
                }).unwrap();
            }

            #[test]
            fn shl(a in rand_u(), b in any::<usize>()) {
                objc::rc::autoreleasepool(|| {
                    let b = b % 256; // so it doesn't overflow
                    let result = execute_kernel("test_uint_shl", (a, Small(b)));
                    prop_assert_eq!(result, a << b);
                    Ok(())
                }).unwrap();
            }

            #[test]
            fn shr(a in rand_u(), b in any::<usize>()) {
                objc::rc::autoreleasepool(|| {
                    let b = b % 256; // so it doesn't overflow
                    let result = execute_kernel("test_uint_shr", (a, Small(b)));
                    prop_assert_eq!(result, a >> b);
                    Ok(())
                }).unwrap();
            }
        }
    }

    mod fp_tests {
        use lambdaworks_math::unsigned_integer::traits::U32Limbs;
        use proptest::collection;

        use super::*;

        enum FEOrInt {
            Elem(FE),
            Int(u32),
        }

        fn execute_kernel(name: &str, a: &FE, b: FEOrInt) -> FE {
            let state = MetalState::new(None).unwrap();
            let pipeline = state.setup_pipeline(name).unwrap();

            // conversion needed because of possible difference of endianess between host and
            // device (Metal's UnsignedInteger has 32bit limbs).
            let a = a.value().to_u32_limbs();
            let result_buffer = state.alloc_buffer::<u32>(8);

            let (command_buffer, command_encoder) = match b {
                FEOrInt::Elem(b) => {
                    let b = b.value().to_u32_limbs();
                    let a_buffer = state.alloc_buffer_data(&a);
                    let b_buffer = state.alloc_buffer_data(&b);

                    state.setup_command(
                        &pipeline,
                        Some(&[(0, &a_buffer), (1, &b_buffer), (2, &result_buffer)]),
                    )
                }
                FEOrInt::Int(b) => {
                    let a_buffer = state.alloc_buffer_data(&a);
                    let b_buffer = state.alloc_buffer_data(&[b]);

                    state.setup_command(
                        &pipeline,
                        Some(&[(0, &a_buffer), (1, &b_buffer), (2, &result_buffer)]),
                    )
                }
            };

            let threadgroup_size = MTLSize::new(1, 1, 1);
            let threadgroup_count = MTLSize::new(1, 1, 1);

            command_encoder.dispatch_thread_groups(threadgroup_count, threadgroup_size);
            command_encoder.end_encoding();

            command_buffer.commit();
            command_buffer.wait_until_completed();

            let limbs = MetalState::retrieve_contents::<u32>(&result_buffer);
            FE::from_raw(&U::from_u32_limbs(&limbs))
        }

        prop_compose! {
            fn rand_u32()(n in any::<u32>()) -> u32 { n }
        }

        prop_compose! {
            fn rand_limbs()(vec in collection::vec(rand_u32(), 8)) -> Vec<u32> {
                vec
            }
        }

        prop_compose! {
            fn rand_felt()(limbs in rand_limbs()) -> FE {
                FE::from(&U256::from_u32_limbs(&limbs))
            }
        }

        use FEOrInt::{Elem, Int};

        proptest! {
            #[test]
            fn add(a in rand_felt(), b in rand_felt()) {
                objc::rc::autoreleasepool(|| {
                    let result = execute_kernel("test_fpbn254_add", &a, Elem(b.clone()));
                    prop_assert_eq!(result, a + b);
                    Ok(())
                }).unwrap();
            }

            #[test]
            fn sub(a in rand_felt(), b in rand_felt()) {
                objc::rc::autoreleasepool(|| {
                    let result = execute_kernel("test_fpbn254_sub", &a, Elem(b.clone()));
                    prop_assert_eq!(result, a - b);
                    Ok(())
                }).unwrap();
            }

            #[test]
            fn mul(a in rand_felt(), b in rand_felt()) {
                objc::rc::autoreleasepool(|| {
                    let result = execute_kernel("test_fpbn254_mul", &a, Elem(b.clone()));
                    prop_assert_eq!(result, a * b);
                    Ok(())
                }).unwrap();
            }

            #[test]
            fn pow(a in rand_felt(), b in rand_u32()) {
                objc::rc::autoreleasepool(|| {
                    let result = execute_kernel("test_fpbn254_pow", &a, Int(b));
                    prop_assert_eq!(result, a.pow(b));
                    Ok(())
                }).unwrap();
            }
        }
    }

    mod ec_tests {
        use lambdaworks_math::unsigned_integer::traits::U32Limbs;

        use super::*;

        pub type P = ShortWeierstrassProjectivePoint<BN254Curve>;

        fn execute_kernel(name: &str, p: &P, q: &P) -> Vec<u32> {
            let state = MetalState::new(None).unwrap();
            let pipeline = state.setup_pipeline(name).unwrap();

            // conversion needed because of possible difference of endianess between host and
            // device (Metal's UnsignedInteger has 32bit limbs).
            let p_coordinates: Vec<u32> = p
                .coordinates()
                .into_iter()
                .map(|felt| felt.value().to_u32_limbs())
                .flatten()
                .collect();
            let q_coordinates: Vec<u32> = q
                .coordinates()
                .into_iter()
                .map(|felt| felt.value().to_u32_limbs())
                .flatten()
                .collect();
            let p_buffer = state.alloc_buffer_data(&p_coordinates);
            let q_buffer = state.alloc_buffer_data(&q_coordinates);
            let result_buffer = state.alloc_buffer::<u32>(24);

            let (command_buffer, command_encoder) = state.setup_command(
                &pipeline,
                Some(&[(0, &p_buffer), (1, &q_buffer), (2, &result_buffer)]),
            );

            let threadgroup_size = MTLSize::new(1, 1, 1);
            let threadgroup_count = MTLSize::new(1, 1, 1);

            command_encoder.dispatch_thread_groups(threadgroup_count, threadgroup_size);
            command_encoder.end_encoding();

            command_buffer.commit();
            command_buffer.wait_until_completed();

            MetalState::retrieve_contents::<u32>(&result_buffer)
        }

        prop_compose! {
            fn rand_u128()(n in any::<u128>()) -> u128 { n }
        }

        prop_compose! {
            fn rand_point()(n in rand_u128()) -> P {
                BN254Curve::generator().operate_with_self(n)
            }
        }

        proptest! {
            #[test]
            fn add(p in rand_point(), q in rand_point()) {
                objc::rc::autoreleasepool(|| {
                    let result = execute_kernel("bn254_add", &p, &q);
                    let cpu_result = p
                        .operate_with(&q)
                        .to_u32_limbs();
                    prop_assert_eq!(result, cpu_result);
                    Ok(())
                }).unwrap();
            }

            #[test]
            fn add_with_self(p in rand_point()) {
                objc::rc::autoreleasepool(|| {
                    let result = execute_kernel("bn254_add", &p, &p);
                    let cpu_result: Vec<u32> = p
                        .operate_with_self(2_u64)
                        .to_u32_limbs();
                    prop_assert_eq!(result, cpu_result);
                    Ok(())
                }).unwrap();
            }

            #[test]
            fn add_with_infinity_rhs(p in rand_point()) {
                objc::rc::autoreleasepool(|| {
                    let infinity = p.operate_with_self(0_u64);
                    let result = execute_kernel("bn254_add", &p, &infinity);
                    let cpu_result: Vec<u32> = p
                        .operate_with(&infinity)
                        .to_u32_limbs();
                    prop_assert_eq!(result, cpu_result);
                    Ok(())
                }).unwrap();
            }

            #[test]
            fn add_with_infinity_lhs(p in rand_point()) {
                objc::rc::autoreleasepool(|| {
                    let infinity = p.operate_with_self(0_u64);
                    let result = execute_kernel("bn254_add", &infinity, &p);
                    let cpu_result: Vec<u32> = infinity
                        .operate_with(&p)
                        .to_u32_limbs();
                    prop_assert_eq!(result, cpu_result);
                    Ok(())
                }).unwrap();
            }
        }

        #[test]
        fn infinity_plus_infinity_should_equal_infinity() {
            let infinity = BN254Curve::generator().operate_with_self(0_u64);
            let result = execute_kernel("bn254_add", &infinity, &infinity);
            let cpu_result: Vec<u32> = infinity.operate_with(&infinity).to_u32_limbs();
            assert_eq!(result, cpu_result);
        }
    }
}
