#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="${DXVK_OUTPUT_DIR:-$repo_dir/dist/dxvk}"
proton_dir="${1:-${PROTON_DIR:-}}"
backup_dir="${DXVK_BACKUP_DIR:-$repo_dir/.backup/dxvk-$(date +%Y%m%d-%H%M%S)}"

[[ -f "$dist/d3d11.dll" && -f "$dist/dxgi.dll" ]] || {
  echo "Missing built DLLs in $dist. Run scripts/build-dxvk.sh first." >&2
  exit 1
}
[[ -n "$proton_dir" && -d "$proton_dir" ]] || {
  echo "Usage: $0 /path/to/Proton" >&2
  exit 2
}

mapfile -t candidates < <(find "$proton_dir" -type d -path '*/dxvk*' 2>/dev/null | sort -u)
target=""
for d in "${candidates[@]}"; do
  if [[ -f "$d/d3d11.dll" && -f "$d/dxgi.dll" ]]; then target="$d"; break; fi
done
if [[ -z "$target" ]]; then
  echo "Could not find the Proton DXVK directory containing d3d11.dll and dxgi.dll." >&2
  find "$proton_dir" -type f \( -name d3d11.dll -o -name dxgi.dll \) -print >&2 || true
  exit 1
fi

mkdir -p "$backup_dir"
cp -a "$target/d3d11.dll" "$backup_dir/d3d11.dll"
cp -a "$target/dxgi.dll" "$backup_dir/dxgi.dll"
cp "$dist/d3d11.dll" "$target/d3d11.dll"
cp "$dist/dxgi.dll" "$target/dxgi.dll"
printf '%s\n' "Installed patched DXVK into $target" "Backup: $backup_dir"
printf '%s\n' "Note: updating/reinstalling Proton may replace these files."
