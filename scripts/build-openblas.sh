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
    # make reuses stale in-tree objects across flag or toolchain changes
    git clean -qfdx
    cd ..
  fi
}

configure_and_build() {
  local install_prefix="${1:-install}"
  local static_only="${2:-false}"

  case "$(uname -s)" in
    MINGW*|MSYS*)
      build_with_cmake "${install_prefix}"
      ;;
    *)
      build_with_make "${install_prefix}" "${static_only}"
      ;;
  esac
}

build_with_make() {
  local install_prefix="$1"
  local static_only="$2"

  # make -C OpenBLAS resolves a relative PREFIX inside the source tree
  [[ "${install_prefix}" = /* ]] || install_prefix="$(pwd)/${install_prefix}"

  local make_args=(
    DYNAMIC_ARCH=1
    TARGET="${TARGET_CPU}"
    NUM_THREADS=64
    USE_OPENMP=0
    COMMON_OPT=-O3
  )

  if [[ "$(uname -s)" == "Linux" ]]; then
    # \$$: survive make's $$->$ and the recipe shell's expansion
    make_args+=('LDFLAGS=-Wl,-rpath,\$$ORIGIN')
  fi

  if [[ -z "${MAKE_CMD:-}" ]]; then
    # Only the conda-toolchain (casadi) variant links a Fortran runtime; every other
    # artifact ships the self-contained C LAPACK.
    make_args+=(NOFORTRAN=1)
  fi

  if [[ "${static_only}" == "true" ]]; then
    make_args+=(NO_SHARED=1)
  fi

  echo "MAKE_ARGS: ${make_args[*]}"

  # The 'shared' goal already pulls in 'libs netlib' and is .NOTPARALLEL; naming them
  # as separate goals would let them race.
  ${MAKE_CMD:-make} -C OpenBLAS -j "$(getconf _NPROCESSORS_ONLN)" "${make_args[@]}" shared

  echo "Installing OpenBLAS..."
  ${MAKE_CMD:-make} -C OpenBLAS "${make_args[@]}" PREFIX="${install_prefix}" install

  if [[ "$(uname -s)" == "Darwin" && "${static_only}" != "true" ]]; then
    verify_macos_abi "${install_prefix}"
  fi
}

build_with_cmake() {
  local install_prefix="$1"
  local build_dir="${BUILD_DIR:-build}"

  local cmake_args=(
    -S OpenBLAS
    -B "${build_dir}"
    -G Ninja
    -DDYNAMIC_ARCH=ON
    -DTARGET="${TARGET_CPU}"
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_STATIC_LIBS=ON
    -DBUILD_SHARED_LIBS=ON
    -DUSE_OPENMP=OFF
    -DNUM_THREADS=64
    -DCMAKE_INSTALL_PREFIX="${install_prefix}"
  )

  echo "CMAKE_ARGS: ${cmake_args[*]}"
  cmake "${cmake_args[@]}"

  echo "Building and installing OpenBLAS..."
  cmake --build "${build_dir}" --parallel "$(nproc)" --target install
}

verify_macos_abi() {
  local install_prefix="$1"
  local dylib links count=0 bad=0

  echo "Verifying macOS libgfortran linkage of built OpenBLAS libraries..."
  while IFS= read -r dylib; do
    count=$((count + 1))
    links=$(otool -L "${dylib}")
    echo "== ${dylib}"
    echo "${links}"
    if [[ -n "${MAKE_CMD:-}" ]]; then
      if ! grep -q '@rpath/libgfortran' <<<"${links}"; then
        echo "ERROR: ${dylib} does not link @rpath/libgfortran (conda gfortran was not used)" >&2
        bad=1
      fi
      if grep 'libgfortran' <<<"${links}" | grep -qv '@rpath'; then
        echo "ERROR: ${dylib} links libgfortran outside @rpath (ABI-incompatible with CasADi)" >&2
        bad=1
      fi
    elif grep -q 'libgfortran' <<<"${links}"; then
      echo "ERROR: ${dylib} links libgfortran (NOFORTRAN build must be self-contained)" >&2
      bad=1
    fi
  done < <(find "${install_prefix}" -name 'libopenblas*.dylib' -type f)

  if [[ "${count}" -eq 0 ]]; then
    echo "ERROR: no libopenblas dylib found under ${install_prefix}" >&2
    exit 1
  fi
  if [[ "${bad}" -ne 0 ]]; then
    echo "macOS libgfortran check failed" >&2
    exit 1
  fi
  echo "macOS libgfortran check passed"
}

main() {
  local prefix=""
  local static_only=false
  local target=""

  # Parse CLI arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --prefix)
        prefix="$2"
        shift 2
        ;;
      --target)
        target="$2"
        shift 2
        ;;
      --static-only)
        static_only=true
        shift
        ;;
      -h|--help)
        echo "Usage: $0 [--prefix PATH] [--target CPU] [--static-only]"
        echo "  --prefix PATH      Install prefix (default: install)"
        echo "  --target CPU       Target CPU (default: CORE2 for x86_64, ARMV8 for aarch64)"
        echo "                     Common x86_64 targets: CORE2, HASWELL, SKYLAKEX"
        echo "  --static-only      Build static libraries only (musl/static linking; Linux and macOS)"
        echo "Environment variables:"
        echo "  OPENBLAS_VERSION   OpenBLAS version (required)"
        echo "  TARGET_CPU         Target CPU (overrides --target and defaults)"
        echo "  BUILD_DIR          Build directory (Windows only, default: build)"
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

  # Determine TARGET_CPU: env var takes precedence, then --target arg, then defaults
  if [[ -z "${TARGET_CPU:-}" ]]; then
    if [[ -n "${target}" ]]; then
      TARGET_CPU="${target}"
    elif [[ "${ARCH}" == "x86_64" ]]; then
      TARGET_CPU="CORE2"
    else
      TARGET_CPU="ARMV8"
    fi
  fi
  # getarch matches FORCE_<TARGET> case-sensitively; a lowercase target silently
  # falls back to CPU autodetection under CMake and errors out under make.
  TARGET_CPU=$(printf '%s' "${TARGET_CPU}" | tr '[:lower:]' '[:upper:]')

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
  echo "Target CPU: ${TARGET_CPU}"

  local install_prefix="${prefix:-install}"

  fetch_and_checkout "${OPENBLAS_VERSION}"
  configure_and_build "${install_prefix}" "${static_only}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
