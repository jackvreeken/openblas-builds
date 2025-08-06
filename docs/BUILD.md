# OpenBLAS Build Documentation

## Architecture Overview

The build system uses a matrix strategy with derived variables to minimize code duplication:

- **Composite action** (`.github/actions/setup-build-env`) handles dependency installation
- **Reusable workflow** (`.github/workflows/check-openblas.yml`) manages
  version detection
- **Unified build script** (`scripts/build-openblas.sh`) works across all platforms
- **Smart builds** skip compilation if version/commit hasn't changed

## Platform Matrix

| Runner                         | Manylinux                                         | Architecture | Target CPU |
| ------------------------------ | ------------------------------------------------- | ------------ | ---------- |
| ubuntu-latest                  | manylinux2014, manylinux_2_28,<br/>manylinux_2_34 | x86_64       | NEHALEM    |
| ubuntu-24.04-arm               | manylinux2014, manylinux_2_28,<br/>manylinux_2_34 | aarch64      | ARMV8      |
| windows-latest                 | -                                                 | x64          | NEHALEM    |
| macos-13, macos-14, macos-15   | -                                                 | x86_64       | NEHALEM    |
| macos-14-arm64, macos-15-arm64 | -                                                 | arm64        | ARMV8      |

## Build Configuration

### OpenBLAS CMake Settings

```cmake
-DDYNAMIC_ARCH=TRUE          # Runtime CPU detection
-DTARGET=NEHALEM/ARMV8       # Baseline compatibility
-DCMAKE_BUILD_TYPE=Release   # Optimized build
-DBUILD_SHARED_LIBS=ON       # Build .so/.dylib/.dll
-DBUILD_STATIC_LIBS=ON       # Build .a files
-DUSE_OPENMP=OFF            # Disabled for compatibility
-DNUM_THREADS=64            # Maximum thread support
```

### Platform-Specific Settings

- **Windows**: MinGW Makefiles, gcc/gfortran from MSYS2
- **macOS**: Native toolchain, architecture-specific builds
- **manylinux**: GCC from container, cross-compilation for ARM

## Local Development

### Prerequisites

- Docker (for manylinux testing)
- Git
- Bash

### Testing Builds

```bash
# Quick test with DYNAMIC_ARCH=OFF (faster)
./scripts/test-local.sh manylinux_2_34 x86_64

# Full production test
DYNAMIC_ARCH=TRUE ./scripts/test-local.sh manylinux_2_34 x86_64

# Test ARM64 (requires ARM host)
./scripts/test-local.sh manylinux2014 aarch64
```

### Build Script Usage

```bash
# Use latest version
./scripts/build-openblas.sh

# Specify version and prefix
OPENBLAS_VERSION=v0.3.30 ./scripts/build-openblas.sh --prefix /usr/local

# Environment variables
TARGET_CPU=CORE2 DYNAMIC_ARCH=FALSE ./scripts/build-openblas.sh
```

## CI/CD Workflow

### Trigger Conditions

- **Push/PR**: Always build (manual/automatic)
- **Schedule**: Weekly on Sunday 02:00 UTC
- **Manual**: Via workflow_dispatch

### Version Detection

1. Check input version or fetch latest via GitHub API
1. Get commit hash for the version tag
1. Compare with existing nightly release
1. Skip build if version/commit unchanged (scheduled builds only)

### Release Strategy

- **Nightly**: `nightly` tag, overwritten weekly
- **Tagged**: `{version}-build-{number}` for manual builds
- **Assets**: Platform-specific archives with libraries and headers

## Contributing

### Development Setup

```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run checks manually
pre-commit run --all-files
```

### Code Style

- **Pre-commit hooks**: Automated formatting, linting, and validation
- **ShellCheck**: All shell scripts must pass with error severity
- **YAML/Markdown**: Consistent formatting with yamllint/markdownlint
- **Bash strict mode**: `set -euo pipefail` with proper error handling
- **Functions**: Keep under 40 lines with single responsibility
- **Commit messages**: Use conventional commits format

### Testing Checklist

- [ ] Pre-commit hooks pass: `pre-commit run --all-files`
- [ ] Local manylinux_2_34 x86_64 build succeeds
- [ ] Artifact contains static and shared libraries
- [ ] CMake config files are present
- [ ] Version detection works without network
- [ ] Build script help text is accurate
