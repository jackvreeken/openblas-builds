#!/bin/bash
set -euo pipefail

# Local testing script for manylinux builds
# Usage: ./scripts/test-local.sh [manylinux_version] [arch]

MANYLINUX_VERSION="${1:-manylinux_2_34}"
ARCH="${2:-x86_64}"
OPENBLAS_VERSION="${OPENBLAS_VERSION:-}"  # Let build script determine latest

echo "Testing OpenBLAS build locally with ${MANYLINUX_VERSION}_${ARCH}"

# Validate manylinux version
case "${MANYLINUX_VERSION}" in
  manylinux2014|manylinux_2_28|manylinux_2_34)
    ;;
  *)
    echo "Error: Unsupported manylinux version: ${MANYLINUX_VERSION}"
    echo "Supported versions: manylinux2014, manylinux_2_28, manylinux_2_34"
    exit 1
    ;;
esac

# Validate architecture
case "${ARCH}" in
  x86_64|aarch64)
    ;;
  *)
    echo "Error: Unsupported architecture: ${ARCH}"
    echo "Supported architectures: x86_64, aarch64"
    exit 1
    ;;
esac

# Set target CPU based on architecture
if [[ "${ARCH}" == "aarch64" ]]; then
  TARGET_CPU="ARMV8"
else
  TARGET_CPU="NEHALEM"
fi

CONTAINER_IMAGE="quay.io/pypa/${MANYLINUX_VERSION}_${ARCH}"

echo "Using container: ${CONTAINER_IMAGE}"
echo "Target CPU: ${TARGET_CPU}"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
  echo "Error: Docker is not installed or not in PATH"
  exit 1
fi

# Check if container image exists
echo "Pulling container image..."
if ! docker pull "${CONTAINER_IMAGE}"; then
  echo "Error: Failed to pull container image ${CONTAINER_IMAGE}"
  exit 1
fi

# Create a temporary directory for build artifacts
BUILD_DIR=$(mktemp -d)
echo "Build directory: ${BUILD_DIR}"

# Run the build in container
echo "Starting build in container..."
docker run --rm \
  -v "${PWD}:/work" \
  -w /work \
  -e OPENBLAS_VERSION="${OPENBLAS_VERSION}" \
  -e TARGET_CPU="${TARGET_CPU}" \
  -e ARCH="${ARCH}" \
  -e PLATFORM="${MANYLINUX_VERSION}" \
  -e BUILD_DIR="test-build" \
  -e DYNAMIC_ARCH="${DYNAMIC_ARCH:-OFF}" \
  "${CONTAINER_IMAGE}" \
  bash -c "
    # Install dependencies
    if command -v yum &> /dev/null; then
      yum update -y
      yum install -y git cmake3 make gcc-c++ gfortran
      ln -sf /usr/bin/cmake3 /usr/bin/cmake || true
    elif command -v apt-get &> /dev/null; then
      apt-get update
      apt-get install -y git cmake build-essential gfortran
    fi
    
    # Run the build script
    chmod +x scripts/build-openblas.sh
    ./scripts/build-openblas.sh
  "

# Check if build was successful
if [[ -d "test-build/install" ]]; then
  echo "✅ Build successful!"
  echo "Built libraries:"
  find test-build/install -name "*.so*" -o -name "*.a" | head -10
  
  echo ""
  echo "Build artifacts location: test-build/install"
  echo "To clean up: rm -rf test-build OpenBLAS"
else
  echo "❌ Build failed - no install directory found"
  exit 1
fi

echo ""
echo "Local test completed successfully for ${MANYLINUX_VERSION}_${ARCH}"