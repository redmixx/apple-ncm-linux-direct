#!/usr/bin/env bash
set -euo pipefail

interface=""
linux_address=""
apply=false

usage() {
  cat <<'EOF'
Usage: rollback.sh --interface IFACE --linux-address CIDR [--apply]

Removes only the exact IPv4 address from the named interface. Dry-run is the
default. The interface is not brought down; routes and DNS are not changed.
EOF
}

while (($#)); do
  case "$1" in
    --interface) [[ $# -ge 2 ]] || exit 64; interface=$2; shift 2 ;;
    --linux-address) [[ $# -ge 2 ]] || exit 64; linux_address=$2; shift 2 ;;
    --apply) apply=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
done

[[ -n $interface && -n $linux_address ]] || { usage >&2; exit 64; }
[[ $interface =~ ^[[:alnum:]_][[:alnum:]_.:-]*$ ]] || { echo "ERROR: unsafe interface name" >&2; exit 64; }
[[ $linux_address =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || { echo "ERROR: invalid IPv4 CIDR" >&2; exit 64; }
command -v ip >/dev/null 2>&1 || { echo "ERROR: ip is not installed" >&2; exit 69; }

echo "Mode: $($apply && echo APPLY || echo DRY-RUN)"
echo "Command: ip address del $linux_address dev $interface"
echo "Default route: unchanged"
echo "DNS: unchanged"

if ! $apply; then
  echo "No changes made."
  exit 0
fi

[[ $EUID -eq 0 ]] || { echo "ERROR: --apply requires root" >&2; exit 77; }
if ! ip link show dev "$interface" >/dev/null 2>&1; then
  echo "ERROR: interface $interface does not exist" >&2
  exit 65
fi
if ! ip -o addr show dev "$interface" | grep -Eqw -- "$linux_address"; then
  echo "NOTHING TO REMOVE: $linux_address is not configured on $interface"
  exit 0
fi
ip address del "$linux_address" dev "$interface"
echo "Removed $linux_address from $interface"
