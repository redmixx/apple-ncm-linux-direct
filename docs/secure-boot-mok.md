# Secure Boot and MOK signing

When UEFI Secure Boot is enabled and the kernel enforces module signatures, a
locally built module is not trusted merely because it has matching `vermagic`.
The module must be signed by a key whose certificate is trusted by the running
kernel. Ubuntu commonly uses the Machine Owner Key (MOK) workflow for this.

> [!CAUTION]
> **NEVER publish, attach, paste, or commit `MOK.priv`.** Anyone holding that
> private key can sign kernel code trusted by machines where its certificate is
> enrolled. Keep it mode `0600`, back it up securely, and exclude it from Git.

## Audit first

```bash
mokutil --sb-state
mokutil --list-enrolled
cat /sys/module/module/parameters/sig_enforce 2>/dev/null
modinfo cdc_ncm | grep -E '^(filename|signer|sig_key|sig_hashalgo):'
```

## Generate a local MOK pair

Use a protected directory outside the repository:

```bash
sudo install -d -m 700 /root/module-signing
sudo openssl req -new -x509 -newkey rsa:3072 \
  -sha512 -nodes -days 3650 \
  -subj "/CN=Local module signing/" \
  -keyout /root/module-signing/MOK.priv \
  -outform DER \
  -out /root/module-signing/MOK.der
sudo chmod 600 /root/module-signing/MOK.priv
```

Display only certificate metadata, never the private key:

```bash
openssl x509 -inform DER -in /root/module-signing/MOK.der \
  -noout -subject -dates -fingerprint -sha256
```

## Request enrolment

```bash
sudo mokutil --import /root/module-signing/MOK.der
mokutil --list-new
```

`mokutil` asks for a one-time enrolment password. It is used in the firmware-side
MOK Manager after reboot; it is not the private-key password and should not be
stored in the repository.

During the planned reboot, select:

1. **Enroll MOK**
2. **Continue**
3. **Yes**
4. enter the one-time enrolment password
5. **Reboot**

After boot, confirm the certificate appears in `mokutil --list-enrolled`.

## Sign a module

Use `sign-file` from the exact running kernel build tree:

```bash
sudo /lib/modules/"$(uname -r)"/build/scripts/sign-file sha512 \
  /root/module-signing/MOK.priv \
  /root/module-signing/MOK.der \
  /absolute/path/to/cdc_ncm.ko
```

Verify metadata before loading:

```bash
modinfo /absolute/path/to/cdc_ncm.ko | \
  grep -E '^(signer|sig_key|sig_hashalgo|vermagic):'
```

Enrolment requires a reboot. Signing after a certificate is already enrolled
does not. This repository does not automate either action.
