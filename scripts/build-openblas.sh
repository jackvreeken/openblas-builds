#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# OpenBLAS Build Script
# Works on Linux (including manylinux containers), macOS, and Windows (Git Bash/MSYS2)


fetch_and_checkout() {
  local version="$1"
  echo "Building OpenBLAS ${version}"

  if [[ ! -d "OpenBLAS" ]]; then
    echo "Cloning OpenBLAS repository (depth 1 for tag ${version})..."
    git clone --depth 1 --branch "${version}" https://github.com/OpenMathLib/OpenBLAS.git
  else
    cd OpenBLAS
    echo "Checking out OpenBLAS ${version}..."
    git fetch origin "${version}"
    git checkout "${version}"
    cd ..
  fi
}

configure_and_build() {
  local install_prefix="${1:-install}"
  local static_only="${2:-false}"

  local cmake_args=(
    -S OpenBLAS
    -B "${BUILD_DIR}"
    -G "Ninja"
    -DDYNAMIC_ARCH="${DYNAMIC_ARCH}"
    -DTARGET="${TARGET_CPU}"
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_STATIC_LIBS=ON
    -DUSE_OPENMP=OFF
    -DNUM_THREADS=64
    -DCMAKE_INSTALL_PREFIX="${install_prefix}"
  )

  # Add RPATH=$ORIGIN for Linux builds to look in local directory first
  if [[ "$(uname -s)" == "Linux" ]]; then
    cmake_args+=(
      -DCMAKE_INSTALL_RPATH='$ORIGIN'
      -DCMAKE_BUILD_RPATH='$ORIGIN'
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    )
  fi

  if [[ "$static_only" == "true" ]]; then
    echo "Configuring for static-only build (musl/static linking)"
    cmake_args+=(-DBUILD_SHARED_LIBS=OFF)
  else
    cmake_args+=(-DBUILD_SHARED_LIBS=ON)
  fi

  echo "CMAKE_ARGS: ${cmake_args[*]}"

  cmake "${cmake_args[@]}"

  echo "Building and installing OpenBLAS..."
  cmake --build "${BUILD_DIR}" --parallel "$(nproc)" --target install
}

main() {
  local prefix=""
  local static_only=false

  # Parse CLI arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --prefix)
        prefix="$2"
        shift 2
        ;;
      --static-only)
        static_only=true
        shift
        ;;
      -h|--help)
        echo "Usage: $0 [--prefix PATH] [--static-only]"
        echo "  --prefix PATH      Install prefix (default: install)"
        echo "  --static-only      Build static libraries only (for musl/static linking)"
        echo "Environment variables:"
        echo "  OPENBLAS_VERSION   OpenBLAS version (required)"
        echo "  TARGET_CPU         Target CPU (default: CORE2 / ARMV8)"
        echo "  BUILD_DIR          Build directory (default: build)"
        echo "  DYNAMIC_ARCH       Dynamic arch (default: ON)"
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
  done

  # Get the architecture of the current machine
  ARCH=$(uname -m)
  if [[ "${ARCH}" == "x86_64" ]]; then
    TARGET_CPU="${TARGET_CPU:-CORE2}"
  else
    TARGET_CPU="${TARGET_CPU:-ARMV8}"
  fi

  # Set defaults
  BUILD_DIR="${BUILD_DIR:-build}"
  DYNAMIC_ARCH="${DYNAMIC_ARCH:-ON}"

  # Check if ARCH and TARGET_CPU are set
  if [[ -z "${ARCH:-}" ]]; then
    echo "ARCH is not set" >&2
    exit 1
  fi
  if [[ -z "${TARGET_CPU:-}" ]]; then
    echo "TARGET_CPU is not set" >&2
    exit 1
  fi

  if [[ -z "${OPENBLAS_VERSION:-}" ]]; then
    echo "Error: OPENBLAS_VERSION environment variable is required" >&2
    echo "This should be set by the workflow's check step" >&2
    exit 1
  fi

  echo "Building OpenBLAS version: ${OPENBLAS_VERSION}"

  local install_prefix="${prefix:-install}"

  fetch_and_checkout "${OPENBLAS_VERSION}"
  configure_and_build "${install_prefix}" "${static_only}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
