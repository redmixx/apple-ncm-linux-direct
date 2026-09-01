# Benchmarks

## Verified measurement

| Parameter | Value |
| --- | --- |
| USB mode | USB 3.2 SuperSpeed Plus Gen 2x1 |
| Negotiated bus speed | `10000M` |
| IP family | IPv4 point-to-point `/30` |
| Measured `iperf3` throughput | approximately 5.2 Gb/s |

This is a tested configuration, not a universal performance promise.

## Reproducible procedure

1. Confirm the route uses the direct USB interface.
2. Record link speed from Linux sysfs and `lsusb -t`.
3. Start `iperf3 -s` on the peer.
4. Run P1, P4, and reverse P4 for at least 10 seconds.
5. Record retransmissions, CPU use, MTU, cable, kernel, and direction.
6. Repeat after the system reaches steady thermal conditions.

```bash
./scripts/test-link.sh --interface enx0123456789ab --peer 10.55.0.1
```

## Reporting results

Report the median of repeated runs and distinguish gigabits per second (Gb/s)
from gigabytes per second (GB/s). Redact hostnames, MAC addresses, serial
numbers, usernames, and unrelated network configuration.

## MTU

The project defaults to the existing interface MTU. Higher MTUs may improve or
worsen results depending on both endpoints and the NCM implementation. Establish
a stable baseline before experimenting and do not change MTU automatically.
