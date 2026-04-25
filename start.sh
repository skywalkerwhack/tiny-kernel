#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="skywalkerwhack/tiny-kernel"
WORKFLOW="build-linux-tinyconfig.yml"
RELEASE_TAG="latest"
ASSET_NAME="linux-boot-artifacts.tar.gz"
RUN_REF="${RUN_REF:-$(git -C "${SCRIPT_DIR}" branch --show-current || true)}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

wait_for_run_id() {
  local previous_run_id="$1"
  local attempts=30
  local run_id=""

  while (( attempts > 0 )); do
    run_id="$(
      gh run list \
        --repo "${REPO}" \
        --workflow "${WORKFLOW}" \
        --branch "${RUN_REF}" \
        --event workflow_dispatch \
        --limit 1 \
        --json databaseId \
        --jq '.[0].databaseId // empty'
    )"

    if [[ -n "${run_id}" && "${run_id}" != "${previous_run_id}" ]]; then
      printf '%s\n' "${run_id}"
      return 0
    fi

    sleep 2
    attempts=$((attempts - 1))
  done

  echo "timed out waiting for workflow run id" >&2
  return 1
}

download_artifacts() {
  rm -f "${SCRIPT_DIR}/${ASSET_NAME}"

  gh release download "${RELEASE_TAG}" \
    --repo "${REPO}" \
    --dir "${SCRIPT_DIR}" \
    --pattern "${ASSET_NAME}" \
    --clobber

  tar -xzf "${SCRIPT_DIR}/${ASSET_NAME}" -C "${SCRIPT_DIR}"
}

boot_qemu() {
  exec qemu-system-x86_64 \
    -m 1G \
    -enable-kvm \
    -kernel "${SCRIPT_DIR}/bzImage" \
    -initrd "${SCRIPT_DIR}/initrd.img" \
    -nographic \
    -append "console=ttyS0 nokaslr"
}

main() {
  require_cmd gh
  require_cmd tar
  require_cmd qemu-system-x86_64

  if [[ -z "${RUN_REF}" ]]; then
    echo "could not determine git branch; set RUN_REF explicitly" >&2
    exit 1
  fi

  gh auth status >/dev/null

  previous_run_id="$(
    gh run list \
      --repo "${REPO}" \
      --workflow "${WORKFLOW}" \
      --branch "${RUN_REF}" \
      --event workflow_dispatch \
      --limit 1 \
      --json databaseId \
      --jq '.[0].databaseId // empty'
  )"

  echo "triggering ${WORKFLOW} on ${RUN_REF}"
  gh workflow run "${WORKFLOW}" \
    --repo "${REPO}" \
    --ref "${RUN_REF}"

  echo "waiting for workflow run id"
  run_id="$(wait_for_run_id "${previous_run_id}")"

  echo "watching workflow run ${run_id}"
  gh run watch "${run_id}" \
    --repo "${REPO}" \
    --exit-status

  echo "downloading ${RELEASE_TAG}/${ASSET_NAME}"
  download_artifacts

  echo "booting qemu"
  boot_qemu
}

main "$@"
