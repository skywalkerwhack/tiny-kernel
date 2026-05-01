#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_VERSION="${KERNEL_VERSION:-7.0}"
KERNEL_TARBALL="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_SOURCE_DIR="${SCRIPT_DIR}/linux"
CCACHE_DIR="${SCRIPT_DIR}/.ccache"
JOBS="${JOBS:-$(nproc)}"

DEBIAN_PACKAGES=(
  bc
  bison
  build-essential
  ccache
  cpio
  curl
  flex
  libelf-dev
  libssl-dev
  dwarves
  xz-utils
)

require_file() {
  local path="$1"

  if [[ ! -e "${path}" ]]; then
    echo "missing required file: ${path}" >&2
    exit 1
  fi
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
    return
  fi

  if have_cmd sudo; then
    sudo "$@"
    return
  fi

  echo "need root privileges to run: $*" >&2
  exit 1
}

install_dependencies() {
  if ! have_cmd apt-get; then
    echo "apt-get not found; install dependencies manually:" >&2
    printf '  %s\n' "${DEBIAN_PACKAGES[*]}" >&2
    exit 1
  fi

  export DEBIAN_FRONTEND=noninteractive

  run_as_root apt-get update
  run_as_root apt-get install -y --no-install-recommends "${DEBIAN_PACKAGES[@]}"
}

ensure_dependencies() {
  local missing=()
  local required_cmds=(curl tar make gcc cpio gzip xz)
  local cmd

  for cmd in "${required_cmds[@]}"; do
    if ! have_cmd "${cmd}"; then
      missing+=("${cmd}")
    fi
  done

  if (( ${#missing[@]} == 0 )); then
    return
  fi

  echo "installing missing build dependencies: ${missing[*]}"
  install_dependencies
}

fetch_kernel_source() {
  local tarball_path="${SCRIPT_DIR}/${KERNEL_TARBALL}"
  local kernel_url="https://cdn.kernel.org/pub/linux/kernel/v7.x/${KERNEL_TARBALL}"

  if [[ ! -f "${tarball_path}" ]]; then
    echo "downloading ${KERNEL_TARBALL}"
    curl -fL "${kernel_url}" -o "${tarball_path}"
  fi

  rm -rf "${KERNEL_SOURCE_DIR}"

  echo "extracting ${KERNEL_TARBALL}"
  tar -xf "${tarball_path}" -C "${SCRIPT_DIR}"
  mv "${SCRIPT_DIR}/linux-${KERNEL_VERSION}" "${KERNEL_SOURCE_DIR}"
}

build_kernel() {
  echo "building bzImage from .config"
  mkdir -p "${CCACHE_DIR}"

  cp "${SCRIPT_DIR}/.config" "${KERNEL_SOURCE_DIR}/.config"

  (
    cd "${KERNEL_SOURCE_DIR}"

    if have_cmd ccache; then
      export CCACHE_DIR
      export CCACHE_BASEDIR="${SCRIPT_DIR}"
      export CCACHE_COMPILERCHECK=content
      export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-500M}"
      ccache --zero-stats || true
      make CC="ccache gcc" HOSTCC="ccache gcc" olddefconfig
      make CC="ccache gcc" HOSTCC="ccache gcc" -j"${JOBS}" bzImage
      ccache --show-stats || true
    else
      make olddefconfig
      make -j"${JOBS}" bzImage
    fi
  )

  cp "${KERNEL_SOURCE_DIR}/arch/x86/boot/bzImage" "${SCRIPT_DIR}/bzImage"
}

build_initrd() {
  echo "building initrd.img from initramfs/"

  (
    cd "${SCRIPT_DIR}/initramfs"
    find . -print0 \
      | cpio --null --create --format=newc --owner=0:0 \
      | gzip -9 > "${SCRIPT_DIR}/initrd.img"
  )
}

main() {
  require_file "${SCRIPT_DIR}/.config"
  require_file "${SCRIPT_DIR}/initramfs/init"
  require_file "${SCRIPT_DIR}/initramfs/bin/busybox"

  ensure_dependencies
  fetch_kernel_source
  build_kernel
  build_initrd

  echo "artifacts ready:"
  echo "  ${SCRIPT_DIR}/bzImage"
  echo "  ${SCRIPT_DIR}/initrd.img"
}

main "$@"
