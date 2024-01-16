// This file is used to generate the benchmark report for the GPU exploration middleware.

#[cfg(feature = "gpu-benchmarks")]
use {
    mopro_core::middleware::gpu_explorations::run_msm_benchmark,
    std::{cmp, env, fs::File, io::Write},
};

#[cfg(feature = "gpu-benchmarks")]
fn main() {
    let path = env::current_dir()
        .unwrap()
        .join("benchmarks/gpu_explorations/msm_bench.csv");
    let mut file = File::create(path).unwrap();
    writeln!(
        file,
        "num_msm,avg_processing_time(ms),total_processing_time(ms),memory_allocated(Bytes)"
    )
    .unwrap();
    // generate trials = [1, 500, 1_000, 1_500, ..., 10_000]
    let trials: Vec<u32> = (0..21).map(|i| cmp::max(i * 500, 1)).collect();
    for each in trials {
        let bench_data = run_msm_benchmark(Some(each)).unwrap();
        writeln!(
            file,
            "{},{},{},{}",
            bench_data.num_msm,
            bench_data.avg_processing_time,
            bench_data.total_processing_time,
            bench_data.allocated_memory,
        )
        .unwrap();
    }
}
