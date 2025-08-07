#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# OpenBLAS Build Script
# Works on Linux (including manylinux containers), macOS, and Windows (Git Bash/MSYS2)

get_latest_openblas_version() {
  local latest_version

  latest_version=$(curl -s -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/OpenMathLib/OpenBLAS/releases/latest" | \
    grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4 2>/dev/null)

  if [[ -z "$latest_version" ]]; then
    echo "Error: Could not fetch latest OpenBLAS version from GitHub" >&2
    echo "This could be due to network issues or GitHub API limits" >&2
    exit 1
  else
    echo "$latest_version"
  fi
}

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

  local cmake_args=(
    -S OpenBLAS
    -B "${BUILD_DIR}"
    -G "Ninja"
    -DDYNAMIC_ARCH="${DYNAMIC_ARCH}"
    -DTARGET="${TARGET_CPU}"
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_SHARED_LIBS=ON
    -DBUILD_STATIC_LIBS=ON
    -DUSE_OPENMP=OFF
    -DNUM_THREADS=64
    -DCMAKE_INSTALL_PREFIX="${install_prefix}"
  )

  echo "CMAKE_ARGS: ${cmake_args[*]}"

  cmake "${cmake_args[@]}"

  echo "Building and installing OpenBLAS..."
  cmake --build "${BUILD_DIR}" --parallel "$(nproc)" --target install
}

main() {
  local prefix=""

  # Parse CLI arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --prefix)
        prefix="$2"
        shift 2
        ;;
      -h|--help)
        echo "Usage: $0 [--prefix PATH]"
        echo "  --prefix PATH    Install prefix (default: install)"
        echo "Environment variables:"
        echo "  OPENBLAS_VERSION  OpenBLAS version (default: latest)"
        echo "  TARGET_CPU        Target CPU (default: HASWELL / ARMV8)"
        echo "  BUILD_DIR         Build directory (default: build)"
        echo "  DYNAMIC_ARCH      Dynamic arch (default: ON)"
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
    TARGET_CPU="${TARGET_CPU:-HASWELL}"
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
    echo "Fetching latest OpenBLAS version..."
    OPENBLAS_VERSION=$(get_latest_openblas_version)
    echo "Latest version found: ${OPENBLAS_VERSION}"
  fi

  local install_prefix="${prefix:-install}"

  fetch_and_checkout "${OPENBLAS_VERSION}"
  configure_and_build "${install_prefix}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
