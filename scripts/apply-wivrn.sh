#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${WIVRN_SOURCE_DIR:-${1:-}}"

if [[ -z "${source_dir}" ]]; then
  echo "Usage: WIVRN_SOURCE_DIR=/path/to/WiVRn $0" >&2
  exit 2
fi

cd "$source_dir"
git apply --check "$repo_dir/patches/wivrn-gaze-export.patch"
git apply "$repo_dir/patches/wivrn-gaze-export.patch"
echo "WiVRn gaze-export changes applied."
