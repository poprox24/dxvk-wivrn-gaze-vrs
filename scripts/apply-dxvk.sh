#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${DXVK_SOURCE_DIR:-${1:-}}"

if [[ -z "${source_dir}" ]]; then
  echo "Usage: DXVK_SOURCE_DIR=/path/to/dxvk $0" >&2
  exit 2
fi

cd "$source_dir"
git apply --check "$repo_dir/patches/dxvk-gaze-vrs.patch"
git apply "$repo_dir/patches/dxvk-gaze-vrs.patch"
echo "DXVK gaze-VRS changes applied."
