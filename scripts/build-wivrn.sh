#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Allow callers to override the location, but never silently build an arbitrary WiVRn revision.
source_dir="${WIVRN_SOURCE_DIR:-$repo_dir/.work/WiVRn}"
build_dir="${WIVRN_BUILD_DIR:-$source_dir/build-gaze-vrs}"

# Pinned to the latest tested WiVRn release. The headset client must use this same release.
# Do not change these independently: mismatched server/client versions are unsupported.
# shellcheck disable=SC1091
source "$repo_dir/versions.env"

if [[ ! -d "$source_dir/.git" ]]; then
  echo "WiVRn source not found: $source_dir" >&2
  echo "Clone WiVRn $WIVRN_VERSION and set WIVRN_SOURCE_DIR, or use the checkout instructions in README.md." >&2
  exit 1
fi

actual_commit="$(git -C "$source_dir" rev-parse HEAD)"
if [[ "$actual_commit" != "$WIVRN_COMMIT" ]]; then
  echo "Wrong WiVRn revision." >&2
  echo "  required: $WIVRN_VERSION ($WIVRN_COMMIT)" >&2
  echo "  found:    $(git -C "$source_dir" describe --always --dirty 2>/dev/null || echo "$actual_commit")" >&2
  echo >&2
  echo "Use the same WiVRn release as the headset client. Do NOT build the Android client from this repository." >&2
  exit 1
fi

"$repo_dir/scripts/apply-wivrn.sh" "$source_dir"

# PC-only build. The headset APK/client is deliberately NOT built here.
# GIT_TAG keeps the generated server/dashboard version aligned with the release tag.
cmake -S "$source_dir" -B "$build_dir" -GNinja \
  -DWIVRN_BUILD_CLIENT=OFF \
  -DWIVRN_BUILD_SERVER=ON \
  -DWIVRN_BUILD_SERVER_LIBRARY=OFF \
  -DWIVRN_BUILD_DASHBOARD=ON \
  -DWIVRN_BUILD_WIVRNCTL=ON \
  -DGIT_TAG="$WIVRN_VERSION" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build "$build_dir"

echo "WiVRn $WIVRN_VERSION PC build complete."
echo "Android/headset client was not built."
