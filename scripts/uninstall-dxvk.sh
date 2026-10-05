#!/usr/bin/env bash
set -euo pipefail

backup_dir="${1:-}"
[[ -d "$backup_dir" ]] || { echo "Usage: $0 /path/to/backup" >&2; exit 2; }

proton_dir="${PROTON_DIR:-}"
[[ -n "$proton_dir" && -d "$proton_dir" ]] || { echo "Set PROTON_DIR=/path/to/Proton" >&2; exit 2; }

[[ -f "$backup_dir/d3d11.dll" && -f "$backup_dir/dxgi.dll" ]] || {
  echo "Backup is missing d3d11.dll and/or dxgi.dll." >&2
  exit 1
}

target="$proton_dir/files/lib/wine/dxvk/x86_64-windows"

[[ -d "$target" ]] || {
  echo "Could not find target DXVK directory: $target" >&2
  exit 1
}

cp "$backup_dir/d3d11.dll" "$target/d3d11.dll"
cp "$backup_dir/dxgi.dll" "$target/dxgi.dll"

echo "Restored original DXVK DLLs in $target"