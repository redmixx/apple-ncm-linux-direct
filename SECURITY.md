# Security Policy

## Supported versions

Until the first tagged release, security fixes apply to the current `main`
branch.

## Reporting a vulnerability

Open a private GitHub security advisory after the repository is published. Do
not include real private keys, credentials, or unredacted system logs. Until a
private advisory channel exists, do not publish exploit details in a public
issue.

## Operational safety

Kernel modules execute with full kernel privilege. Building a module from source
that does not exactly match the running vendor kernel can cause crashes, data
loss, or subtle corruption. Unloading `cdc_ncm` interrupts every active device
using it.

- Prefer a supported distribution kernel containing the upstream fix.
- Keep physical or out-of-band recovery access.
- Test on a non-production host first.
- Inspect every command printed by a dry-run.
- Never commit a MOK private key or any other signing key.
- Do not disable Secure Boot as a shortcut.

The scripts intentionally do not install, sign, load, unload, or persist kernel
modules.
