#!/usr/bin/env bash
set -u

kernel_release=$(uname -r)
module=""

usage() {
  echo "Usage: check-module.sh [--kernel-release REL] /path/to/cdc_ncm.ko"
}

while (($#)); do
  case "$1" in
    --kernel-release)
      [[ $# -ge 2 ]] || { echo "ERROR: --kernel-release requires a value" >&2; exit 64; }
      kernel_release=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
    *)
      [[ -z $module ]] || { echo "ERROR: only one module path may be supplied" >&2; exit 64; }
      module=$1
      shift
      ;;
  esac
done

[[ -n $module ]] || { usage >&2; exit 64; }
if [[ ! -f $module ]]; then
  echo "ERROR: module not found: $module" >&2
  exit 66
fi

for command in file modinfo; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "ERROR: required command is missing: $command" >&2
    exit 69
  fi
done

echo "== File =="
file "$module"

echo
echo "== Module metadata =="
modinfo "$module" | grep -E '^(filename|license|description|alias|depends|name|vermagic|signer|sig_key|sig_hashalgo):' || true

metadata=$(modinfo "$module")
if0=NO
if2=NO
grep -Eiq '^alias:[[:space:]]+usb:.*v05acp1905.*in00' <<<"$metadata" && if0=YES
grep -Eiq '^alias:[[:space:]]+usb:.*v05acp1905.*in02' <<<"$metadata" && if2=YES

built_vermagic=$(modinfo -F vermagic "$module" 2>/dev/null || true)
distribution_vermagic=$(modinfo -k "$kernel_release" -F vermagic cdc_ncm 2>/dev/null || true)
signer=$(modinfo -F signer "$module" 2>/dev/null || true)

echo
echo "== Compatibility summary =="
echo "05ac:1905 interface 0 alias: $if0"
echo "05ac:1905 interface 2 alias: $if2"
echo "Target kernel release: $kernel_release"
echo "Built vermagic: ${built_vermagic:-UNKNOWN}"
echo "Distribution cdc_ncm vermagic: ${distribution_vermagic:-UNKNOWN}"
if [[ -n $built_vermagic && -n $distribution_vermagic && $built_vermagic == "$distribution_vermagic" ]]; then
  echo "Vermagic match: YES"
else
  echo "Vermagic match: NO OR UNKNOWN"
fi
echo "Signer: ${signer:-UNSIGNED}"

if [[ $if0 == YES && $if2 == YES ]]; then
  exit 0
fi
exit 2
