#!/usr/bin/env bash
set -euo pipefail

backup_dir="${1:-}"
[[ -d "$backup_dir" ]] || { echo "Usage: $0 /path/to/backup" >&2; exit 2; }

proton_dir="${PROTON_DIR:-}"
[[ -n "$proton_dir" && -d "$proton_dir" ]] || { echo "Set PROTON_DIR=/path/to/Proton" >&2; exit 2; }

mapfile -t candidates < <(find "$proton_dir" -type d -path '*/dxvk*' 2>/dev/null | sort -u)
target=""
for d in "${candidates[@]}"; do
  [[ -f "$backup_dir/d3d11.dll" && -f "$d/d3d11.dll" ]] && [[ -f "$d/dxgi.dll" ]] && { target="$d"; break; }
done
[[ -n "$target" ]] || { echo "Could not find target DXVK directory." >&2; exit 1; }

cp "$backup_dir/d3d11.dll" "$target/d3d11.dll"
cp "$backup_dir/dxgi.dll" "$target/dxgi.dll"
echo "Restored original DXVK DLLs in $target"
