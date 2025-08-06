#!/bin/bash
set -euo pipefail

# OpenBLAS Build Script
# Works on Linux (including manylinux containers), macOS, and Windows (Git Bash/MSYS2)

# Get latest OpenBLAS version if not specified
get_latest_openblas_version() {
  local latest_version
  latest_version=$(git ls-remote --tags https://github.com/OpenMathLib/OpenBLAS.git 2>/dev/null | \
    grep -E 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' | \
    sed 's/.*refs\/tags\///' | \
    sort -V | \
    tail -1)
  
  if [[ -z "$latest_version" ]]; then
    echo "Error: Could not fetch latest OpenBLAS version from GitHub" >&2
    echo "This could be due to network issues or GitHub API limits" >&2
    exit 1
  else
    echo "$latest_version"
  fi
}

# Default values
if [[ -z "${OPENBLAS_VERSION}" ]]; then
  echo "Fetching latest OpenBLAS version..."
  OPENBLAS_VERSION=$(get_latest_openblas_version)
  echo "Latest version found: ${OPENBLAS_VERSION}"
fi
TARGET_CPU="${TARGET_CPU:-NEHALEM}"
ARCH="${ARCH:-x86_64}"
PLATFORM="${PLATFORM:-linux}"
BUILD_DIR="${BUILD_DIR:-build}"
INSTALL_PREFIX="${INSTALL_PREFIX:-${BUILD_DIR}/install}"
# Set to OFF for faster testing builds (defaults to ON for production)
DYNAMIC_ARCH="${DYNAMIC_ARCH:-TRUE}"

echo "Building OpenBLAS ${OPENBLAS_VERSION} for ${PLATFORM} ${ARCH}"
echo "Target CPU: ${TARGET_CPU}, Dynamic Arch: ${DYNAMIC_ARCH}"

# Detect platform if not set
if [[ -z "${PLATFORM:-}" ]]; then
  case "$(uname -s)" in
    Linux*)     PLATFORM=linux;;
    Darwin*)    PLATFORM=macos;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM=windows;;
    *)          PLATFORM=unknown;;
  esac
fi

# Clone OpenBLAS if not already present
if [[ ! -d "OpenBLAS" ]]; then
  echo "Cloning OpenBLAS repository..."
  git clone https://github.com/OpenMathLib/OpenBLAS.git
fi

cd OpenBLAS

# Checkout specific version
echo "Checking out OpenBLAS ${OPENBLAS_VERSION}..."
git fetch --tags
git checkout "${OPENBLAS_VERSION}"

# Create build directory
mkdir -p "../${BUILD_DIR}"
cd "../${BUILD_DIR}"

# Set up CMAKE_ARGS based on platform
CMAKE_ARGS=(
  -DDYNAMIC_ARCH=${DYNAMIC_ARCH}
  -DTARGET="${TARGET_CPU}"
  -DCMAKE_BUILD_TYPE=Release
  -DBUILD_SHARED_LIBS=ON
  -DBUILD_STATIC_LIBS=ON
  -DUSE_OPENMP=OFF
  -DNUM_THREADS=64
  -DCMAKE_INSTALL_PREFIX="${PWD}/${INSTALL_PREFIX##*/}"
)

# Platform-specific adjustments
case "${PLATFORM}" in
  windows)
    # Windows-specific settings
    CMAKE_ARGS+=(
      -G "MinGW Makefiles"
      -DCMAKE_C_COMPILER=gcc
      -DCMAKE_Fortran_COMPILER=gfortran
    )
    ;;
  macos*)
    # macOS-specific settings
    if [[ "${ARCH}" == "arm64" ]]; then
      CMAKE_ARGS+=(
        -DCMAKE_OSX_ARCHITECTURES=arm64
      )
    else
      CMAKE_ARGS+=(
        -DCMAKE_OSX_ARCHITECTURES=x86_64
      )
    fi
    ;;
  manylinux*)
    # manylinux container settings
    CMAKE_ARGS+=(
      -DCMAKE_C_COMPILER=gcc
      -DCMAKE_Fortran_COMPILER=gfortran
    )
    ;;
esac

# Cross-compilation settings for ARM on x86_64 host (if needed)
if [[ "${ARCH}" == "aarch64" && "$(uname -m)" != "aarch64" ]]; then
  CMAKE_ARGS+=(
    -DCMAKE_SYSTEM_NAME=Linux
    -DCMAKE_SYSTEM_PROCESSOR=aarch64
    -DCMAKE_CROSSCOMPILING=TRUE
  )
fi

echo "Running CMake configuration..."
echo "CMake args: ${CMAKE_ARGS[*]}"

cmake ../OpenBLAS "${CMAKE_ARGS[@]}"

echo "Building OpenBLAS..."
# Use appropriate build command based on platform
if [[ "${PLATFORM}" == "windows" ]]; then
  mingw32-make -j$(nproc)
  mingw32-make install
else
  make -j$(nproc)
  make install
fi

echo "Build completed successfully!"
echo "Installation directory: ${PWD}/${INSTALL_PREFIX##*/}"

# Verify build
echo "Verifying build..."
ls -la "${INSTALL_PREFIX##*/}"/lib/

# Test basic library loading (if possible)
if command -v ldd &> /dev/null && [[ "${PLATFORM}" != "windows" ]]; then
  echo "Library dependencies:"
  find "${INSTALL_PREFIX##*/}"/lib -name "*.so*" -o -name "*.dylib" | head -1 | xargs ldd || true
fi

echo "OpenBLAS build completed for ${PLATFORM} ${ARCH}"