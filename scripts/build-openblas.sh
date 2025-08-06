#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# OpenBLAS Build Script
# Works on Linux (including manylinux containers), macOS, and Windows (Git Bash/MSYS2)

get_latest_openblas_version() {
  local latest_version
  latest_version=$(gh release list --repo OpenMathLib/OpenBLAS --limit 1 --exclude-pre-releases --json tagName --jq '.[0].tagName' 2>/dev/null)

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
  echo "Building OpenBLAS ${version} for ${PLATFORM} ${ARCH}"
  echo "Target CPU: ${TARGET_CPU}, Dynamic Arch: ${DYNAMIC_ARCH}"

  if [[ -z "${PLATFORM:-}" ]]; then
    case "$(uname -s)" in
      Linux*)     PLATFORM=linux;;
      Darwin*)    PLATFORM=macos;;
      MINGW*|MSYS*|CYGWIN*) PLATFORM=windows;;
      *)          PLATFORM=unknown;;
    esac
  fi

  if [[ ! -d "OpenBLAS" ]]; then
    echo "Cloning OpenBLAS repository..."
    git clone https://github.com/OpenMathLib/OpenBLAS.git
  fi

  cd OpenBLAS
  echo "Checking out OpenBLAS ${version}..."
  git fetch --tags
  git checkout "${version}"
  cd ..
}

configure_and_build() {
  local install_prefix="${1:-${BUILD_DIR}/install}"

  mkdir -p "${BUILD_DIR}"
  cd "${BUILD_DIR}"

  local cmake_args=(
    -DDYNAMIC_ARCH="${DYNAMIC_ARCH}"
    -DTARGET="${TARGET_CPU}"
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_SHARED_LIBS=ON
    -DBUILD_STATIC_LIBS=ON
    -DUSE_OPENMP=OFF
    -DNUM_THREADS=64
    -DCMAKE_INSTALL_PREFIX="${install_prefix}"
  )

  case "${PLATFORM}" in
    windows)
      cmake_args+=(
        -G "MinGW Makefiles"
        -DCMAKE_C_COMPILER=gcc
        -DCMAKE_Fortran_COMPILER=gfortran
      )
      ;;
    macos*)
      if [[ "${ARCH}" == "arm64" ]]; then
        cmake_args+=(-DCMAKE_OSX_ARCHITECTURES=arm64)
      else
        cmake_args+=(-DCMAKE_OSX_ARCHITECTURES=x86_64)
      fi
      ;;
    manylinux*)
      cmake_args+=(
        -DCMAKE_C_COMPILER=gcc
        -DCMAKE_Fortran_COMPILER=gfortran
      )
      ;;
  esac

  if [[ "${ARCH}" == "aarch64" && "$(uname -m)" != "aarch64" ]]; then
    cmake_args+=(
      -DCMAKE_SYSTEM_NAME=Linux
      -DCMAKE_SYSTEM_PROCESSOR=aarch64
      -DCMAKE_CROSSCOMPILING=TRUE
    )
  fi

  echo "Running CMake configuration..."
  echo "CMake args: ${cmake_args[*]}"
  cmake ../OpenBLAS "${cmake_args[@]}"

  echo "Building OpenBLAS..."
  if [[ "${PLATFORM}" == "windows" ]]; then
    mingw32-make -j"$(nproc)"
  else
    make -j"$(nproc)"
  fi

  echo "Installing OpenBLAS..."
  cmake --install . --prefix "${install_prefix}"

  echo "Build completed successfully!"
  echo "Installation directory: ${install_prefix}"

  echo "Verifying build..."
  ls -la "${install_prefix}"/lib*/

  if command -v ldd &> /dev/null && [[ "${PLATFORM}" != "windows" ]]; then
    echo "Library dependencies:"
    find "${install_prefix}"/lib* -name "*.so*" -o -name "*.dylib" | head -1 | xargs ldd || true
  fi

  echo "OpenBLAS build completed for ${PLATFORM} ${ARCH}"
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
        echo "  --prefix PATH    Install prefix (default: build/install)"
        echo "Environment variables:"
        echo "  OPENBLAS_VERSION  OpenBLAS version (default: latest)"
        echo "  TARGET_CPU        Target CPU (default: NEHALEM)"
        echo "  ARCH              Architecture (default: x86_64)"
        echo "  PLATFORM          Platform (default: auto-detect)"
        echo "  BUILD_DIR         Build directory (default: build)"
        echo "  DYNAMIC_ARCH      Dynamic arch (default: TRUE)"
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
  done

  # Set defaults
  TARGET_CPU="${TARGET_CPU:-NEHALEM}"
  ARCH="${ARCH:-x86_64}"
  PLATFORM="${PLATFORM:-linux}"
  BUILD_DIR="${BUILD_DIR:-build}"
  DYNAMIC_ARCH="${DYNAMIC_ARCH:-TRUE}"

  if [[ -z "${OPENBLAS_VERSION:-}" ]]; then
    echo "Fetching latest OpenBLAS version..."
    OPENBLAS_VERSION=$(get_latest_openblas_version)
    echo "Latest version found: ${OPENBLAS_VERSION}"
  fi

  local install_prefix="${prefix:-${BUILD_DIR}/install}"

  fetch_and_checkout "${OPENBLAS_VERSION}"
  configure_and_build "${install_prefix}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
