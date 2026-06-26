#!/usr/bin/env bash
# Provision the conda-forge Fortran/C/C++ toolchain for the macOS "casadi" OpenBLAS
# variant.
#
# Why this exists:
#   This variant targets consumers that load OpenBLAS in the same process as binaries
#   built against the conda-forge gfortran 12 runtime (libgfortran < 13) -- e.g.
#   CasADi's published binaries. The default macOS build uses the runner's Homebrew
#   gcc (gcc 15, libgfortran >= 13), which is fine for most consumers but
#   ABI-incompatible with that runtime; this build uses the matching toolchain.
#
#   The conda compilers need their activation environment (rpath link args, -isysroot,
#   *FLAGS), so instead of exporting bare compiler paths this script exposes $CMAKE,
#   which runs cmake inside the activated env (`micromamba run`). build-openblas.sh
#   calls ${CMAKE:-cmake}, so configure + build run under the correct toolchain.
set -euo pipefail

# --- Pins (immutable: version + sha256) --------------------------------------
MICROMAMBA_VERSION="2.8.1-0"
MICROMAMBA_SHA256="de71a646b73af92dd663e6ddc78993a6a4d47ea28b5d8908c3cc2b9c3077e528"
SDK_URL="https://github.com/phracker/MacOSX-SDKs/releases/download/11.0-11.1/MacOSX11.1.sdk.tar.xz"
SDK_SHA256="9b86eab03176c56bb526de30daa50fa819937c54b280364784ce431885341bf6"

# conda-forge toolchain -- mirrors casadi/action-setup-compiler.
# fortran-compiler==1.6.0 pins gfortran 12; the explicit libgfortran<13 specs keep
# the runtime library package on the matching major so the env is deterministic.
CONDA_SPECS=(
  "fortran-compiler==1.6.0"
  "c-compiler==1.6.0"
  "cxx-compiler==1.6.0"
  "libgfortran<13"
  "libgfortran5<13"
  "libcxx==16.0.6"
  "cmake"
  "make"
)

main() {
  if [[ "$(uname)" != "Darwin" ]]; then
    echo "setup-macos-toolchain.sh is macOS-only (uname=$(uname))" >&2
    exit 1
  fi

  local work="${RUNNER_TEMP:-/tmp}"
  local mamba_bin="${work}/bin/micromamba"
  local mamba_root="${work}/micromamba"
  local env_prefix="${work}/openblas-toolchain"
  local sdk_dir="${work}/MacOSX11.1.sdk"

  echo "::group::Install micromamba ${MICROMAMBA_VERSION}"
  mkdir -p "${work}/bin"
  curl -fL --retry 3 -o "${mamba_bin}" \
    "https://github.com/mamba-org/micromamba-releases/releases/download/${MICROMAMBA_VERSION}/micromamba-osx-arm64"
  echo "${MICROMAMBA_SHA256}  ${mamba_bin}" | shasum -a 256 -c -
  chmod +x "${mamba_bin}"
  echo "::endgroup::"

  echo "::group::Create conda-forge toolchain env"
  MAMBA_ROOT_PREFIX="${mamba_root}" "${mamba_bin}" create -y \
    -p "${env_prefix}" \
    --override-channels -c conda-forge \
    --platform osx-arm64 \
    "${CONDA_SPECS[@]}"
  echo "::endgroup::"

  echo "::group::Install pinned macOS SDK"
  curl -fL --retry 3 -o "${work}/sdk.tar.xz" "${SDK_URL}"
  echo "${SDK_SHA256}  ${work}/sdk.tar.xz" | shasum -a 256 -c -
  tar -xf "${work}/sdk.tar.xz" -C "${work}"   # yields ${work}/MacOSX11.1.sdk
  echo "::endgroup::"

  # Wrapper so cmake runs inside the activated env (inheriting FC/CC/CXX, *FLAGS and
  # the rpath link args). It must be a single executable, not a multi-word command
  # string: build-openblas.sh runs with IFS=$'\n\t', so a space-separated ${CMAKE}
  # would not word-split and would be treated as one bogus command name.
  local cmake_wrapper="${work}/bin/cmake-conda"
  cat > "${cmake_wrapper}" <<EOF
#!/usr/bin/env bash
exec "${mamba_bin}" run -r "${mamba_root}" -p "${env_prefix}" cmake "\$@"
EOF
  chmod +x "${cmake_wrapper}"

  # The SDK / deployment target must be set before activation, so export them job-wide.
  {
    echo "CMAKE=${cmake_wrapper}"
    echo "SDKROOT=${sdk_dir}"
    echo "CONDA_BUILD_SYSROOT=${sdk_dir}"
    echo "MACOSX_DEPLOYMENT_TARGET=11.0"
  } >> "${GITHUB_ENV}"

  echo "Toolchain ready:"
  MAMBA_ROOT_PREFIX="${mamba_root}" "${mamba_bin}" run -p "${env_prefix}" gfortran --version | head -1
  MAMBA_ROOT_PREFIX="${mamba_root}" "${mamba_bin}" run -p "${env_prefix}" cmake --version | head -1
}

main "$@"
