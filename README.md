# OpenBLAS Multi-Platform Builds

Automated weekly builds of [OpenBLAS](https://www.openblas.net/) for multiple
platforms with runtime CPU detection and native ARM compilation.

## Supported Platforms

| Platform                                      | Architectures   | Container/Runner |
| --------------------------------------------- | --------------- | ---------------- |
| manylinux2014, manylinux_2_28, manylinux_2_34 | x86_64, aarch64 | PyPA containers  |
| macOS 13, 14, 15                              | x86_64, arm64   | Native runners   |
| Windows                                       | x64             | Native runners   |

## Why This Exists

OpenBLAS releases don't always include pre-built binaries for all platforms. This repository fills that gap by automatically building the latest OpenBLAS version weekly for common deployment targets, with optimized settings for maximum compatibility.

## Quick Start

Download the latest build from [Releases](../../releases) or run locally:

```bash
# Test build locally (requires Docker)
./scripts/test-local.sh manylinux_2_34 x86_64

# Build with specific version
OPENBLAS_VERSION=v0.3.30 ./scripts/build-openblas.sh --prefix /usr/local
```

## Build Details

- **Settings**: `DYNAMIC_ARCH=TRUE`, `TARGET=NEHALEM/ARMV8`, `USE_OPENMP=OFF`
- **Outputs**: Static/shared libraries, headers, CMake configs
- **Schedule**: Weekly on Sundays (02:00 UTC) if new version available
- **Releases**: `nightly` (latest) and `{version}-build-{number}` (tagged)

For complete build documentation, see [BUILD.md](docs/BUILD.md).

## License

Same as OpenBLAS. See the [OpenBLAS repository](https://github.com/OpenMathLib/OpenBLAS) for details.
