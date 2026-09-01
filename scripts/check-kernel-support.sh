#!/usr/bin/env bash
set -u

usage() {
  cat <<'EOF'
Usage: check-kernel-support.sh [--module MODULE_OR_PATH] [--product 1905|1902]

Read module metadata and check for Apple interface 0 and 2 aliases.
No system state is changed.
EOF
}

module=cdc_ncm
product=1905

while (($#)); do
  case "$1" in
    --module)
      [[ $# -ge 2 ]] || { echo "ERROR: --module requires a value" >&2; exit 64; }
      module=$2
      shift 2
      ;;
    --product)
      [[ $# -ge 2 ]] || { echo "ERROR: --product requires a value" >&2; exit 64; }
      product=${2,,}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [[ ! $product =~ ^[0-9a-f]{4}$ ]]; then
  echo "ERROR: product must be a four-digit hexadecimal USB product ID" >&2
  exit 64
fi

if ! command -v modinfo >/dev/null 2>&1; then
  echo "CDC_NCM SUPPORT: UNKNOWN"
  echo "PATCH MAY BE REQUIRED"
  echo "REASON: modinfo is not installed"
  exit 3
fi

if ! metadata=$(modinfo "$module" 2>&1); then
  echo "CDC_NCM SUPPORT: UNKNOWN"
  echo "PATCH MAY BE REQUIRED"
  echo "REASON: modinfo could not inspect $module"
  printf '%s\n' "$metadata" >&2
  exit 3
fi

vendor_product="v05acp${product}"
if0=false
if2=false
if grep -Eiq "^alias:[[:space:]]+usb:.*${vendor_product}.*in00" <<<"$metadata"; then
  if0=true
fi
if grep -Eiq "^alias:[[:space:]]+usb:.*${vendor_product}.*in02" <<<"$metadata"; then
  if2=true
fi

printf 'MODULE: %s\n' "$module"
printf 'KERNEL: %s\n' "$(uname -r)"
printf 'APPLE DEVICE: 05ac:%s\n' "$product"
printf 'INTERFACE 0 ALIAS: %s\n' "${if0^^}"
printf 'INTERFACE 2 ALIAS: %s\n' "${if2^^}"

if $if0 && $if2; then
  echo "CDC_NCM SUPPORT: PRESENT"
  echo "PATCH NOT REQUIRED"
  exit 0
fi

echo "CDC_NCM SUPPORT: MISSING OR INCOMPLETE"
echo "PATCH MAY BE REQUIRED"
exit 2
