# Troubleshooting

## 1. `lsusb` shows `05ac:1905`, but speed is `480M`

`480M` is USB 2.0 High Speed, not USB 3.x. The likely causes are a charge-only
or USB 2.0 cable, an adapter that lacks SuperSpeed lanes, a USB 2.0 port, or an
incomplete connection.

Try a short certified data cable and a direct USB 3.x/USB4-capable port. Confirm
speed from the matching device directory in `/sys/bus/usb/devices/.../speed`.

## 2. Speed is `10000M`, but `cdc_ncm` reports `bind() failure`

The physical link is SuperSpeed+, but the driver probably lacks the Apple
private-interface quirk. Check aliases for both interface numbers:

```bash
./scripts/check-kernel-support.sh --product 1905
```

If both aliases are absent, prefer a newer or backported distribution kernel.
Otherwise build only from exact matching source. Do not repeatedly rebind the
generic driver while the system is carrying important traffic.

## 3. Module built, but loading says `Key was rejected by service`

Secure Boot/module signature enforcement rejected an unsigned or untrusted
module. Do not disable Secure Boot as a shortcut. Enrol a local MOK, sign the
module, and confirm `modinfo` reports the expected signer. See
[Secure Boot and MOK](secure-boot-mok.md).

## 4. Interfaces exist, but ping fails

The driver can bind without either peer having an IPv4 address. Check:

```bash
ip -br link
ip -br addr
ip route get 10.55.0.1
```

Confirm that Mac and Linux use different addresses in the same `/30`, both
interfaces are up, and the route selects the USB interface. Check host firewalls
without changing the default route or DNS.

## 5. Link negotiates 10 Gb/s, but `iperf3` measures about 5 Gb/s

This can be normal. `10000M` describes USB signalling, not guaranteed TCP
payload throughput. CDC-NCM framing, USB transfer sizes, host-controller and
driver behaviour, CPU scheduling, TCP direction, and stream count all add
overhead.

Record P1, P4, and reverse P4 results. Do not advertise 10 Gb/s application
throughput unless it is measured reproducibly.

## 6. `modinfo` has the aliases, but no `enx...` device appears

Check which module is actually loaded, inspect the exact USB interfaces with
`lsusb -v` (possibly requiring elevated read access), and read relevant `dmesg`
lines. A vendor kernel can ship a different module than the source tree you
inspected.

## 7. Apple PID is `1902`, not `1905`

`1902` has its own upstream change. The patch in this repository intentionally
does not rewrite its product ID. Use `--product 1902` for inspection and prefer
a kernel containing upstream commit `746fc0787f61`.
