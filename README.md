# Apple Silicon ↔ Linux Direct USB Networking

Direct USB-C networking between Apple Silicon Macs and Linux using Apple CDC-NCM.

```text
Mac mini / Mac Studio / MacBook
        |
        | USB-C / USB4
        | Apple CDC-NCM
        |
Linux / DGX Spark / GX10
        |
        +-- direct IP link
```

This repository documents and automates the safe parts of bringing up a direct
IP link between an Apple Silicon Mac and a Linux host. It includes read-only
diagnostics, kernel support detection, a narrowly scoped upstream patch for
Apple `05ac:1905`, an out-of-tree build helper, temporary IP configuration, and
link tests.

## Verified result

| Item | Result |
| --- | --- |
| USB negotiation | USB 3.2 SuperSpeed Plus Gen 2x1, `10000M` |
| Measured `iperf3` throughput | approximately **5.2 Gb/s** |
| Linux driver | `cdc_ncm` with the Apple private-interface quirk |
| Example subnet | `10.55.0.0/30` |

**A negotiated 10 Gb/s USB link does not imply 10 Gb/s application
throughput.** USB framing, CDC-NCM implementation details, CPU scheduling,
buffering, and the benchmark direction all affect the result.

## Requirements

- An Apple Silicon Mac with a USB-C, Thunderbolt, or USB4 port.
- A Linux host with a USB controller capable of USB device attachment.
- A full-featured data cable rated for the desired USB speed.
- Linux tools: `bash`, `iproute2`, `usbutils`, `kmod`, `make`, `patch`, and the
  exact kernel headers/source needed by your distribution.
- Optional: `mokutil` for Secure Boot inspection and `iperf3` for throughput.
- Physical or out-of-band access before replacing or unloading a network
  driver.

Prefer a distribution kernel that already contains the upstream quirk. An
out-of-tree module should be the fallback, not the first choice.

## Supported and tested hardware

The direct-Mac quirk uses Apple VID `05ac` and currently known PIDs:

- `1905`: accepted upstream in commit
  [`a5148bc2fa27`](https://github.com/torvalds/linux/commit/a5148bc2fa27092862ac4b9e7b5c8340d60cff34),
  included in mainline Linux 7.1 and newer.
- `1902`: added later in commit
  [`746fc0787f61`](https://github.com/torvalds/linux/commit/746fc0787f616da418ffc04a110296fe95d53491);
  check your actual module because distribution backports vary.

Tested configuration:

- Apple Silicon Mac mini M4 running macOS 26.5.2.
- ASUS Ascent GX10 / DGX Spark-class host running Ubuntu 24.04.4 with an
  NVIDIA-flavoured Linux 6.17 kernel.
- Apple device `05ac:1905`.
- `10000M` negotiation and approximately 5.2 Gb/s measured throughput.

Other Apple Silicon Macs and Linux systems may work, but are not claimed as
hardware-validated by this repository.

For the release-by-release evidence, related work, and upstream limitations,
see [Upstream status](docs/upstream-status.md).

## Quick diagnosis

On Linux, connect the cable and run:

```bash
./scripts/diagnose.sh
./scripts/check-kernel-support.sh
```

Both scripts are read-only. A healthy patched or natively supported system
usually shows:

- `05ac:1905` (or another supported Apple PID) in `lsusb`;
- `5000M`, `10000M`, or faster in sysfs/`lsusb -t`;
- aliases for interfaces `00` and `02` in `modinfo cdc_ncm`;
- two `enx...` network interfaces bound to `cdc_ncm`.

If `lsusb` sees `05ac:1905` but the kernel logs contain `bind() failure` and no
network interface appears, see [Kernel patch requirement](#kernel-patch-requirement).

## Kernel patch requirement

The generic CDC-NCM match expects an interrupt/status endpoint. Apple's private
Mac interfaces do not provide one, so an older kernel can reach
`cdc_ncm_bind()` and fail. Upstream commit `a5148bc2fa27` adds explicit matches
for interface numbers 0 and 2 and points both at
`apple_private_interface_info`, which does not require `FLAG_LINK_INTR`.

Do not decide from the version string alone: vendors backport fixes and may
carry divergent sources. Check the module aliases:

```bash
./scripts/check-kernel-support.sh
```

The supplied patch is an attributed, functionally identical representation of
the eight-line upstream change:

```text
patches/apple-mac-05ac-1905.patch
```

## Build a test module

You must provide `cdc_ncm.c` that matches the running vendor kernel. Headers
alone often do not contain the driver source.

```bash
./scripts/build-cdc-ncm.sh --dry-run \
  --source /path/to/matching/drivers/net/usb/cdc_ncm.c

./scripts/build-cdc-ncm.sh \
  --source /path/to/matching/drivers/net/usb/cdc_ncm.c \
  --output "$PWD/build/my-kernel"
```

The script checks headers, `Module.symvers`, compiler availability, patch
context, aliases, `vermagic`, and SHA-256. It stops with a `.ko` in the selected
build directory. It never runs `insmod`, `modprobe`, `depmod`, or copies files
into `/lib/modules`.

Inspect an existing test module with:

```bash
./scripts/check-module.sh /path/to/cdc_ncm.ko
```

## Secure Boot: sign before loading

When Secure Boot and module signature enforcement are active, an unsigned
module is rejected. Enrol a local Machine Owner Key (MOK), then use the running
kernel's `scripts/sign-file` tool. Never publish the private key.

See [Secure Boot and MOK](docs/secure-boot-mok.md) for the complete procedure.

## Load the module manually

> [!CAUTION]
> Unloading or replacing `cdc_ncm` disconnects every device using that driver.
> A faulty kernel module can hang or panic the host. Do not do this remotely on
> a production machine without physical or out-of-band recovery access.

No repository script loads the module. A planned, manual test typically
requires stopping traffic, unplugging the Mac, unloading the distribution
module, loading the signed test module, and reconnecting the cable:

```bash
sudo modprobe -r cdc_ncm
sudo insmod /absolute/path/to/cdc_ncm.ko
```

This is intentionally not automated. Prefer booting a kernel that contains the
upstream fix.

## Configure a temporary IP link

Linux defaults to dry-run:

```bash
./scripts/configure-link-linux.sh \
  --interface enx0123456789ab \
  --linux-address 10.55.0.2/30 \
  --peer-address 10.55.0.1
```

Review the printed commands, then explicitly apply them:

```bash
sudo ./scripts/configure-link-linux.sh --apply \
  --interface enx0123456789ab \
  --linux-address 10.55.0.2/30 \
  --peer-address 10.55.0.1
```

Configure the Mac side as described in [macOS setup](docs/macos.md). These
commands do not change the default route, DNS, or unrelated interfaces.

## Test ping and throughput

Start `iperf3 -s` on the peer, then run from Linux:

```bash
./scripts/test-link.sh \
  --interface enx0123456789ab \
  --peer 10.55.0.1
```

The script checks the route and ping, then runs `iperf3` with one stream, four
streams, and four reverse streams. If `iperf3` is missing, it reports that fact
and does not install anything.

## Rollback

Rollback also defaults to dry-run and removes only the exact example address:

```bash
./scripts/rollback.sh \
  --interface enx0123456789ab \
  --linux-address 10.55.0.2/30

sudo ./scripts/rollback.sh --apply \
  --interface enx0123456789ab \
  --linux-address 10.55.0.2/30
```

If a test module was loaded, restore the distribution driver only during a
maintenance window. Rebooting into the unmodified distribution kernel is the
cleanest rollback.

## Troubleshooting

Common cases are documented in [Troubleshooting](docs/troubleshooting.md):

- Apple device found but only `480M`;
- `10000M` together with `bind() failure`;
- `Key was rejected by service`;
- interfaces exist but ping fails;
- 10 Gb/s negotiated but approximately 5 Gb/s measured.

## Safety boundaries

- Diagnostics and support checks are read-only.
- IP configuration and rollback are dry-run unless `--apply` is present.
- Nothing installs packages automatically.
- Nothing builds against guessed or downloaded vendor source automatically.
- Nothing loads, unloads, signs, installs, or persists a kernel module.
- Nothing changes DNS or a default route.

Read [Linux setup](docs/linux.md), [architecture](docs/architecture.md), and
[security policy](SECURITY.md) before testing on important systems.

## Future / experimental uses

Once a stable point-to-point link exists, it may be useful for experiments with:

- EXO;
- heterogeneous inference;
- prefill/decode disaggregation;
- KV-cache transfer;
- direct model API transport.

These are experimental ideas, not guarantees. This project does not claim that
heterogeneous Mac + CUDA inference is production-supported by EXO or any other
runtime.

## License and attribution

Original documentation and scripts are available under the [MIT License](LICENSE).
The patch is derived from Linux `drivers/net/usb/cdc_ncm.c` and upstream commit
`a5148bc2fa27`; it retains upstream attribution and is offered under that
source file's `GPL-2.0-only OR BSD-2-Clause` choice. See
[patch attribution](patches/README.md).
