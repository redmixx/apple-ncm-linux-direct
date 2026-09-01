# Contributing

Contributions are welcome, especially hardware reports, distribution-specific
source lookup guidance, and improvements that preserve the project's safety
boundaries.

## Before opening a pull request

1. Do not include private keys, credentials, serial numbers, hostnames, public
   IP addresses, or logs that identify a private environment.
2. Keep diagnostics read-only and all state-changing scripts dry-run by default.
3. Never add automatic `modprobe`, `insmod`, `depmod`, package installation, MOK
   enrolment, or default-route changes.
4. Run `./scripts/verify-repo.sh`.
5. If available, run `shellcheck scripts/*.sh`.

## Hardware reports

Please include only non-sensitive facts:

- Mac model family and macOS version;
- Linux distribution and full kernel release;
- Apple VID:PID;
- relevant `lsusb -t` speed;
- module aliases and network-interface state;
- test method and throughput direction.

Redact USB serial numbers, MAC addresses, hostnames, usernames, and unrelated
network addresses.

## Patch changes

Kernel patches must cite their exact upstream source or clearly state that they
are experimental. Do not combine unrelated kernel changes into the Apple ID
table patch.
