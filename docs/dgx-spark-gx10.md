# DGX Spark / ASUS Ascent GX10

## Tested configuration

This project was validated with:

- Apple Silicon Mac mini M4;
- ASUS Ascent GX10 / DGX Spark-class Linux host;
- macOS 26.5.2 and Ubuntu 24.04.4;
- NVIDIA-flavoured Linux 6.17 kernel;
- Apple `05ac:1905`;
- USB 3.2 SuperSpeed Plus Gen 2x1;
- `10000M` negotiated bus speed;
- approximately 5.2 Gb/s measured by `iperf3`;
- temporary test subnet `10.55.0.0/30`.

No private hostname, persistent network configuration, accelerator runtime, or
model-serving configuration is required for the direct IP link.

## GX10-specific cautions

- Do not replace an NVIDIA kernel with a generic kernel solely for this patch.
- Obtain source and headers matching the exact NVIDIA kernel build.
- Do not change the high-speed interconnect, CUDA configuration, or model
  containers when testing a separate USB network interface.
- A temporary out-of-tree module is operationally independent of accelerator
  workloads only until it is loaded; unloading a driver is still a kernel-wide
  action and needs a maintenance window.
- Prefer a future NVIDIA/Ubuntu kernel package that backports or includes the
  upstream fix.

## Interpreting two interfaces

The Mac exposes interface numbers 0 and 2, so Linux can create two `enx...`
devices. Determine correspondence by comparing link state, counters, and a
temporary address on only one selected pair. Never assume ordering based on the
interface name alone.
