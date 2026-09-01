#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$script_dir/.." && pwd)
kernel_release=$(uname -r)
source_file=""
output_dir=""
patch_file="$repo_dir/patches/apple-mac-05ac-1905.patch"
dry_run=false

usage() {
  cat <<'EOF'
Usage: build-cdc-ncm.sh --source FILE [options]

Options:
  --source FILE          Exact matching drivers/net/usb/cdc_ncm.c (required)
  --kernel-release REL   Target release (default: uname -r)
  --output DIR           Build directory (default: repo/build/cdc-ncm-REL)
  --patch FILE           Patch to apply
  --dry-run              Validate prerequisites and patch context only
  -h, --help             Show this help

The script never installs, signs, loads, unloads, or persists a module.
EOF
}

while (($#)); do
  case "$1" in
    --source)
      [[ $# -ge 2 ]] || { echo "ERROR: --source requires a value" >&2; exit 64; }
      source_file=$2; shift 2 ;;
    --kernel-release)
      [[ $# -ge 2 ]] || { echo "ERROR: --kernel-release requires a value" >&2; exit 64; }
      kernel_release=$2; shift 2 ;;
    --output)
      [[ $# -ge 2 ]] || { echo "ERROR: --output requires a value" >&2; exit 64; }
      output_dir=$2; shift 2 ;;
    --patch)
      [[ $# -ge 2 ]] || { echo "ERROR: --patch requires a value" >&2; exit 64; }
      patch_file=$2; shift 2 ;;
    --dry-run)
      dry_run=true; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
done

[[ -n $source_file ]] || { echo "ERROR: --source is required; source is never guessed or downloaded" >&2; exit 64; }
[[ -f $source_file ]] || { echo "ERROR: source not found: $source_file" >&2; exit 66; }
[[ -f $patch_file ]] || { echo "ERROR: patch not found: $patch_file" >&2; exit 66; }

kernel_build="/lib/modules/$kernel_release/build"
[[ -e $kernel_build ]] || { echo "ERROR: kernel build link is missing: $kernel_build" >&2; exit 69; }
kernel_build=$(readlink -f "$kernel_build")
[[ -f $kernel_build/Makefile ]] || { echo "ERROR: kernel build Makefile is missing" >&2; exit 69; }
[[ -f $kernel_build/Module.symvers ]] || { echo "ERROR: Module.symvers is missing: $kernel_build/Module.symvers" >&2; exit 69; }

for command in make patch modinfo; do
  command -v "$command" >/dev/null 2>&1 || { echo "ERROR: required command is missing: $command" >&2; exit 69; }
done

compiler=""
for candidate in cc gcc clang; do
  if command -v "$candidate" >/dev/null 2>&1; then compiler=$candidate; break; fi
done
[[ -n $compiler ]] || { echo "ERROR: no C compiler found (cc/gcc/clang)" >&2; exit 69; }

grep -q 'apple_private_interface_info' "$source_file" || {
  echo "ERROR: source lacks apple_private_interface_info; this eight-line patch is not sufficient" >&2
  exit 65
}

if grep -Eq 'USB_DEVICE_INTERFACE_NUMBER\(0x05ac, 0x1905, 0\)' "$source_file" &&
   grep -Eq 'USB_DEVICE_INTERFACE_NUMBER\(0x05ac, 0x1905, 2\)' "$source_file"; then
  echo "PATCH NOT REQUIRED: source already contains both 05ac:1905 aliases"
  exit 0
fi

echo "Kernel release: $kernel_release"
echo "Kernel build: $kernel_build"
echo "Module.symvers: $kernel_build/Module.symvers"
echo "Source: $source_file"
echo "Patch: $patch_file"
echo "Compiler: $($compiler --version | head -1)"
echo "Kernel compiler record: $(cat /proc/version 2>/dev/null || echo UNKNOWN)"

validation_dir=$(mktemp -d)
trap 'rm -rf "$validation_dir"' EXIT
mkdir -p "$validation_dir/drivers/net/usb"
cp "$source_file" "$validation_dir/drivers/net/usb/cdc_ncm.c"
if ! patch --dry-run --silent -p1 -d "$validation_dir" <"$patch_file"; then
  echo "ERROR: patch does not apply cleanly to the supplied source" >&2
  exit 65
fi
echo "Patch dry-run: PASS"

if $dry_run; then
  echo "DRY RUN: no build directory or module was created"
  exit 0
fi

if [[ -z $output_dir ]]; then
  output_dir="$repo_dir/build/cdc-ncm-$kernel_release"
fi
if [[ -e $output_dir ]]; then
  echo "ERROR: output already exists; choose a new --output directory: $output_dir" >&2
  exit 73
fi

module_dir="$output_dir/drivers/net/usb"
mkdir -p "$module_dir"
cp "$source_file" "$module_dir/cdc_ncm.c"
patch --silent -p1 -d "$output_dir" <"$patch_file"
printf 'obj-m := cdc_ncm.o\n' >"$module_dir/Makefile"

make -C "$kernel_build" M="$module_dir" modules

module_file="$module_dir/cdc_ncm.ko"
[[ -f $module_file ]] || { echo "ERROR: build completed without cdc_ncm.ko" >&2; exit 70; }

echo
echo "== Built module =="
file "$module_file"
modinfo "$module_file" | grep -E '^(filename|license|description|alias|depends|name|vermagic|signer|sig_key|sig_hashalgo):' || true

built_vermagic=$(modinfo -F vermagic "$module_file" 2>/dev/null || true)
distribution_vermagic=$(modinfo -k "$kernel_release" -F vermagic cdc_ncm 2>/dev/null || true)
echo "Built vermagic: ${built_vermagic:-UNKNOWN}"
echo "Distribution cdc_ncm vermagic: ${distribution_vermagic:-UNKNOWN}"
if [[ -n $built_vermagic && -n $distribution_vermagic && $built_vermagic == "$distribution_vermagic" ]]; then
  echo "Vermagic match: YES"
else
  echo "Vermagic match: NO OR UNKNOWN"
fi

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$module_file"
else
  shasum -a 256 "$module_file"
fi

"$script_dir/check-module.sh" --kernel-release "$kernel_release" "$module_file"

echo
echo "BUILD COMPLETE: $module_file"
echo "STOPPED BEFORE signing, installation, depmod, modprobe, or insmod."
