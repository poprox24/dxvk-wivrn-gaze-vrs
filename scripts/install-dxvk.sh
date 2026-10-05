#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

dxvk_from="${DXVK_FROM:-${DXVK_OUTPUT_DIR:-}}"
proton_dir="${PROTON_DIR:-}"
backup_dir="${DXVK_BACKUP_DIR:-}"

usage() {
  cat >&2 <<'EOF'
Usage: install-dxvk.sh [--dxvk-from PATH] /path/to/Proton

  --dxvk-from PATH   Where the patched DLLs come from. PATH may be:
                       - a directory containing d3d11.dll and dxgi.dll
                       - a .zip archive containing them (e.g. dxvk-gaze-vrs.zip
                         downloaded from the GitHub Release)
                     If omitted, defaults to $DXVK_FROM, $DXVK_OUTPUT_DIR,
                     or <repo>/dist/dxvk for a local build.

Environment:
  PROTON_DIR         Proton directory (used if no positional argument).
  DXVK_FROM          Default value for --dxvk-from.
  DXVK_OUTPUT_DIR    Fallback DLL source for a local build.
  DXVK_BACKUP_DIR    Where to store the timestamped backup.

Examples:
  # Local build
  ./scripts/install-dxvk.sh "/path/to/Proton"

  # Downloaded release zip
  ./scripts/install-dxvk.sh --dxvk-from ./dxvk-gaze-vrs.zip "/path/to/Proton"

  # Already-unzipped release folder
  ./scripts/install-dxvk.sh --dxvk-from ./dxvk-gaze-vrs "/path/to/Proton"
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dxvk-from)
      [[ -n "${2:-}" ]] || { echo "--dxvk-from needs a value" >&2; usage; }
      dxvk_from="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      ;;
    *)
      if [[ -z "$proton_dir" ]]; then
        proton_dir="$1"
      else
        echo "Unexpected argument: $1" >&2
        usage
      fi
      shift
      ;;
  esac
done

proton_dir="${proton_dir:-${PROTON_DIR:-}}"
backup_dir="${backup_dir:-$repo_dir/.backup/dxvk-$(date +%Y%m%d-%H%M%S)}"

[[ -n "$proton_dir" && -d "$proton_dir" ]] || usage

# If no source given, prefer a local build in <repo>/dist/dxvk.
if [[ -z "$dxvk_from" && -f "$repo_dir/dist/dxvk/d3d11.dll" && -f "$repo_dir/dist/dxvk/dxgi.dll" ]]; then
  dxvk_from="$repo_dir/dist/dxvk"
fi

[[ -n "$dxvk_from" ]] || {
  echo "No DXVK source given, and no local build found at $repo_dir/dist/dxvk." >&2
  echo "Pass --dxvk-from /path/to/dxvk-gaze-vrs.zip (or a directory)." >&2
  exit 1
}

tmp_extract=""
cleanup() { [[ -n "$tmp_extract" && -d "$tmp_extract" ]] && rm -rf "$tmp_extract"; }
trap cleanup EXIT

# If source is a .zip, extract and locate the folder containing both DLLs.
if [[ -f "$dxvk_from" && "$dxvk_from" == *.zip ]]; then
  command -v unzip >/dev/null 2>&1 || { echo "unzip is required to read $dxvk_from" >&2; exit 1; }
  tmp_extract="$(mktemp -d)"
  unzip -q "$dxvk_from" -d "$tmp_extract"
  if [[ -f "$tmp_extract/d3d11.dll" && -f "$tmp_extract/dxgi.dll" ]]; then
    dxvk_from="$tmp_extract"
  else
    found=""
    while IFS= read -r d; do
      if [[ -f "$d/d3d11.dll" && -f "$d/dxgi.dll" ]]; then
        found="$d"; break
      fi
    done < <(find "$tmp_extract" -type d | sort)
    if [[ -z "$found" ]]; then
      echo "Archive $dxvk_from does not contain d3d11.dll and dxgi.dll together." >&2
      find "$tmp_extract" -type f -name '*.dll' >&2 || true
      exit 1
    fi
    dxvk_from="$found"
  fi
fi

[[ -d "$dxvk_from" ]] || { echo "DXVK source '$dxvk_from' is not a directory or .zip." >&2; exit 1; }
[[ -f "$dxvk_from/d3d11.dll" && -f "$dxvk_from/dxgi.dll" ]] || {
  echo "Missing d3d11.dll and/or dxgi.dll in $dxvk_from." >&2
  exit 1
}

target="$proton_dir/files/lib/wine/dxvk/x86_64-windows"

[[ -d "$target" ]] || {
  echo "Could not find the Proton DXVK directory: $target" >&2
  exit 1
}

[[ -f "$target/d3d11.dll" && -f "$target/dxgi.dll" ]] || {
  echo "Missing d3d11.dll and/or dxgi.dll in $target." >&2
  exit 1
}

mkdir -p "$backup_dir"
cp -a "$target/d3d11.dll" "$backup_dir/d3d11.dll"
cp -a "$target/dxgi.dll" "$backup_dir/dxgi.dll"
cp "$dxvk_from/d3d11.dll" "$target/d3d11.dll"
cp "$dxvk_from/dxgi.dll" "$target/dxgi.dll"
printf '%s\n' "Installed patched DXVK into $target" "Backup: $backup_dir"
printf '%s\n' "Note: updating/reinstalling Proton may replace these files."