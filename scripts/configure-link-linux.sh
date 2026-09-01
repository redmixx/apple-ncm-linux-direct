#!/usr/bin/env bash
set -euo pipefail

interface=""
linux_address="10.55.0.2/30"
peer_address="10.55.0.1"
apply=false

usage() {
  cat <<'EOF'
Usage: configure-link-linux.sh --interface IFACE [options]

Options:
  --linux-address CIDR  Address to add (default: 10.55.0.2/30)
  --peer-address IP     Peer shown in the report (default: 10.55.0.1)
  --apply               Apply changes; otherwise print a dry-run

Only the named interface and address are touched. No default route or DNS is
changed.
EOF
}

while (($#)); do
  case "$1" in
    --interface) [[ $# -ge 2 ]] || exit 64; interface=$2; shift 2 ;;
    --linux-address) [[ $# -ge 2 ]] || exit 64; linux_address=$2; shift 2 ;;
    --peer-address) [[ $# -ge 2 ]] || exit 64; peer_address=$2; shift 2 ;;
    --apply) apply=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
done

[[ -n $interface ]] || { echo "ERROR: --interface is required" >&2; exit 64; }
[[ $interface =~ ^[[:alnum:]_.:-]+$ ]] || { echo "ERROR: unsafe interface name" >&2; exit 64; }
[[ $linux_address =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || { echo "ERROR: invalid IPv4 CIDR" >&2; exit 64; }
[[ $peer_address =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "ERROR: invalid peer IPv4" >&2; exit 64; }
command -v ip >/dev/null 2>&1 || { echo "ERROR: ip is not installed" >&2; exit 69; }
ip link show dev "$interface" >/dev/null 2>&1 || { echo "ERROR: interface not found: $interface" >&2; exit 66; }

commands=(
  "ip link set dev $interface up"
  "ip address add $linux_address dev $interface"
)

echo "Mode: $($apply && echo APPLY || echo DRY-RUN)"
echo "Interface: $interface"
echo "Linux address: $linux_address"
echo "Peer address: $peer_address"
echo "Default route: unchanged"
echo "DNS: unchanged"
echo "Commands:"
printf '  %s\n' "${commands[@]}"

if ! $apply; then
  echo "No changes made. Re-run with --apply after review."
  exit 0
fi

[[ $EUID -eq 0 ]] || { echo "ERROR: --apply requires root" >&2; exit 77; }
ip link set dev "$interface" up
ip address add "$linux_address" dev "$interface"
echo "Applied. Verify with: ip -br addr show dev $interface"
echo "Rollback: scripts/rollback.sh --apply --interface $interface --linux-address $linux_address"
