#!/usr/bin/env bash
set -u

interface=""
peer=""
duration=10

usage() {
  cat <<'EOF'
Usage: test-link.sh --interface IFACE --peer IPv4 [--duration SECONDS]

Performs route inspection, ping, iperf3 P1, P4, and reverse P4. Start an iperf3
server on the peer first. No packages or network settings are changed.
EOF
}

while (($#)); do
  case "$1" in
    --interface) [[ $# -ge 2 ]] || exit 64; interface=$2; shift 2 ;;
    --peer) [[ $# -ge 2 ]] || exit 64; peer=$2; shift 2 ;;
    --duration) [[ $# -ge 2 ]] || exit 64; duration=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
done

[[ -n $interface && -n $peer ]] || { usage >&2; exit 64; }
[[ $interface =~ ^[[:alnum:]_.:-]+$ ]] || { echo "ERROR: unsafe interface name" >&2; exit 64; }
[[ $peer =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "ERROR: invalid peer IPv4" >&2; exit 64; }
[[ $duration =~ ^[1-9][0-9]*$ ]] || { echo "ERROR: duration must be a positive integer" >&2; exit 64; }

for command in ip ping; do
  command -v "$command" >/dev/null 2>&1 || { echo "ERROR: required command is missing: $command" >&2; exit 69; }
done

echo "== Interface =="
ip -br link show dev "$interface"
ip -br addr show dev "$interface"

echo
echo "== Route =="
ip route get "$peer"

echo
echo "== Ping =="
ping -I "$interface" -c 5 "$peer"

if ! command -v iperf3 >/dev/null 2>&1; then
  echo
  echo "iperf3 is not installed. Install it manually on both peers to run throughput tests."
  exit 0
fi

echo
echo "== iperf3 P1 =="
iperf3 -c "$peer" -P 1 -t "$duration"

echo
echo "== iperf3 P4 =="
iperf3 -c "$peer" -P 4 -t "$duration"

echo
echo "== iperf3 reverse P4 =="
iperf3 -c "$peer" -R -P 4 -t "$duration"
