# Linux setup

## 1. Diagnose without changing state

```bash
./scripts/diagnose.sh
./scripts/check-kernel-support.sh --product 1905
```

For a Mac reporting `05ac:1902`, pass `--product 1902`. The repository patch is
only for `1905`; use a kernel containing the separate upstream `1902` commit
rather than changing IDs blindly.

## 2. Prefer native kernel support

Linux 7.1 and newer contain the `1905` mainline change. Distribution kernels
may backport it earlier, omit it, or carry a separately built module. The
authoritative test is the pair of module aliases for interfaces 0 and 2.

If the aliases exist but binding still fails, do not apply the same patch
again. Collect descriptors and relevant kernel logs instead.

## 3. Build only from matching source

The source must match the running distribution kernel, including vendor changes.
Examples of legitimate sources include the distribution's exact source package
or its published source repository at the installed package revision.

```bash
./scripts/build-cdc-ncm.sh --dry-run \
  --source /path/to/matching/drivers/net/usb/cdc_ncm.c
```

The build helper requires:

- `/lib/modules/$(uname -r)/build`;
- a complete `Module.symvers`;
- a working Kbuild tree;
- `make`, `patch`, `modinfo`, and a C compiler.

It does not download source because guessing a source revision is unsafe.

## 4. Check the result

```bash
./scripts/check-module.sh /path/to/cdc_ncm.ko
```

Require both `05ac:1905` aliases, matching `vermagic`, and—when Secure Boot is
enforced—a signer trusted by the running kernel.

Matching `vermagic` is necessary but not sufficient. Symbol versions and the
vendor source must also match.

## 5. Schedule any loading test

Loading is deliberately manual. Unloading the current driver can disconnect
unrelated USB networking. Never perform this step on a remote production host
without a tested recovery path.

After reconnecting the cable, inspect:

```bash
lsusb
lsusb -t
ip -br link
ip -br addr
dmesg | tail -150
```

Expected evidence is two `enx...` interfaces and no new `bind() failure`.

## 6. Configure one interface

Use the dry-run-first helper and leave the other Apple NCM interface untouched:

```bash
./scripts/configure-link-linux.sh \
  --interface enx0123456789ab \
  --linux-address 10.55.0.2/30 \
  --peer-address 10.55.0.1
```

Review before using `--apply`.
