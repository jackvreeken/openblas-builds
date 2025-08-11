# OpenBLAS Multi-Platform Builds

Automated weekly builds of [OpenBLAS](https://www.openblas.net/) for multiple
platforms with runtime CPU detection and native ARM compilation.

## Supported Platforms and Targets

| Platform                      | Architectures | CPU Targets    | Container/Runner |
| ----------------------------- | ------------- | -------------- | ---------------- |
| manylinux2014, manylinux_2_28 | x86_64        | CORE2, HASWELL | PyPA containers  |
| manylinux_2_28                | aarch64       | ARMV8          | PyPA containers  |
| musllinux_1_2                 | x86_64        | CORE2, HASWELL | PyPA containers  |
| musllinux_1_2                 | aarch64       | ARMV8          | PyPA containers  |
| macOS 14, 15                  | arm64         | ARMV8          | Native runners   |
| Windows                       | x64           | CORE2, HASWELL | MSYS2 on native  |

### CPU Target Selection

**Important: All builds include `DYNAMIC_ARCH=ON`**, which means they automatically detect and use optimized kernels for your specific CPU at runtime (e.g., AVX-512 on Skylake-X, AVX2 on Haswell, etc.). The TARGET setting only affects the baseline/generic code fallback.

For x86_64 platforms, we provide two build variants:

- **CORE2** (default, no suffix): Maximum compatibility (2006+ CPUs), baseline generic code uses SSE3
- **HASWELL** (suffix: -haswell): Better performance baseline (2013+ CPUs), generic code uses AVX/AVX2

Both variants will automatically use the best available kernels for your CPU. The difference is in the generic/fallback code:

- Use CORE2 (default builds without suffix) for maximum compatibility - works on any x86_64 system
- Use HASWELL builds (with -haswell suffix) for slightly better performance if all your deployment targets are 2013+ CPUs

Example artifact names:

- `openblas-v0.3.30-manylinux2014_x86_64.tar.gz` - CORE2 build (default)
- `openblas-v0.3.30-manylinux2014_x86_64-haswell.tar.gz` - HASWELL build

## Why This Exists

OpenBLAS releases don't always include pre-built binaries for all platforms. This repository fills that gap by automatically building the latest OpenBLAS version weekly for common deployment targets, with optimized settings for maximum compatibility.

## Quick Start

Download the latest build from [Releases](../../releases) or run locally:

```bash
# Build with specific version (default: CORE2 for x86_64)
OPENBLAS_VERSION=v0.3.30 ./scripts/build-openblas.sh

# Build with HASWELL target for better performance
OPENBLAS_VERSION=v0.3.30 ./scripts/build-openblas.sh --target HASWELL

# Show available options
./scripts/build-openblas.sh --help
```

## Build Details

- **Settings**: `DYNAMIC_ARCH=ON`, `USE_OPENMP=OFF`
- **Targets**: `CORE2`/`HASWELL` for x86_64, `ARMV8` for aarch64
- **Outputs**: Static/shared libraries, headers, CMake configs
- **Schedule**: Weekly on Fridays (02:00 UTC) if new version available

## License

Same as OpenBLAS. See the [OpenBLAS repository](https://github.com/OpenMathLib/OpenBLAS) for details.
