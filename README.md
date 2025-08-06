# OpenBLAS Multi-Platform Builds

This repository provides automated builds of OpenBLAS for multiple platforms using GitHub Actions.

## Supported Platforms

- **Linux (manylinux)**:
  - manylinux2014 (x86_64, aarch64)
  - manylinux_2_28 (x86_64, aarch64)
  - manylinux_2_34 (x86_64, aarch64)
- **macOS**:
  - macOS 13 (x86_64)
  - macOS 14 (x86_64, arm64) 
  - macOS 15 (x86_64, arm64)
- **Windows**:
  - Windows (x64)

## Features

- **Dynamic Architecture**: Built with `DYNAMIC_ARCH=TRUE` for runtime CPU detection
- **Optimized Targets**: Uses appropriate CPU targets for maximum compatibility
- **Both Library Types**: Builds both static and shared libraries
- **Native ARM Builds**: Uses native ARM runners (no QEMU emulation)

## Usage

### Automated Builds

Builds are triggered automatically on:
- Push to `main` branch
- Pull requests  
- Manual workflow dispatch
- **Weekly schedule** (Sundays at 02:00 UTC) - automatically builds latest OpenBLAS version

#### Smart Build Detection

The system automatically detects if a build is needed:
- **Manual/Push builds**: Always build
- **Weekly scheduled builds**: Only build if the OpenBLAS version or commit has changed
- If the same version/commit was already built, only updates the nightly release metadata

### Manual Build

You can trigger a build manually from the GitHub Actions tab, optionally specifying an OpenBLAS version.

### Local Testing

Test the manylinux build locally using Docker:

```bash
# Test manylinux_2_34 x86_64 (requires Docker) - uses DYNAMIC_ARCH=OFF for faster builds
./scripts/test-local.sh manylinux_2_34 x86_64

# Test manylinux2014 aarch64 (requires Docker and ARM host)
./scripts/test-local.sh manylinux2014 aarch64

# Test with full dynamic architecture (slower but production-like)
DYNAMIC_ARCH=TRUE ./scripts/test-local.sh manylinux_2_34 x86_64
```

## Build Configuration

### OpenBLAS Settings

- `DYNAMIC_ARCH=TRUE`: Runtime CPU detection (OFF for local testing)
- `TARGET=NEHALEM`: Baseline for x86_64 builds (Intel/AMD)
- `TARGET=ARMV8`: Baseline for ARM64 builds (Apple Silicon, ARM64 Linux)
- `USE_OPENMP=OFF`: Disabled for compatibility
- `NUM_THREADS=64`: Maximum thread support

### Artifacts and Releases

**Build artifacts** are uploaded as:
- `openblas-{version}-{platform}-{arch}.tar.gz` (Linux/macOS)
- `openblas-{version}-{platform}-{arch}.zip` (Windows)

**Releases**:
- **Tagged releases**: `{version}-build-{number}` for manual/push builds
- **Nightly release**: `nightly` tag, updated weekly with latest version
- Each release includes version, commit hash, and build information

Each artifact contains:
- Static libraries (`.a` files)
- Shared libraries (`.so`, `.dylib`, `.dll` files)
- Header files
- CMake configuration files

### Version Detection

- **Automatic**: Fetches latest OpenBLAS version from GitHub
- **Manual override**: Specify version in workflow dispatch
- **Error handling**: Build fails if version detection fails (no fallback)
- **Smart builds**: Skip compilation if version/commit unchanged (weekly builds only)

## Architecture

The build system is designed for minimal code duplication:

- **Single GitHub Actions workflow** with matrix strategy
- **Unified build script** (`scripts/build-openblas.sh`) works on all platforms
- **Platform detection** handled automatically
- **Container-based** manylinux builds using official PyPA images

## Requirements

For local testing:
- Docker (for manylinux builds)
- Git
- Bash (available on all supported platforms)

## License

This build system is provided under the same license as OpenBLAS. See the OpenBLAS repository for license details.