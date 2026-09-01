# Architecture

## Roles

The Mac acts as a USB device exposing Apple's private CDC-NCM functions. Linux
acts as the USB host and binds those functions to `cdc_ncm`.

```text
Apple Silicon Mac                         Linux host
-----------------                        ----------
AppleUSBDeviceNCMPrivateEthernetInterface USB host controller
USB VID:PID 05ac:1905 (or 1902)  <---->   cdc_ncm
macOS enX                                 Linux enx...
10.55.0.1/30                     <---->   10.55.0.2/30
```

Apple exposes two private data functions, using interface numbers 0 and 2. A
supported Linux driver can therefore create two network devices. This project
configures only one selected pair and leaves the second untouched.

## Why older generic binding fails

The generic CDC-NCM driver profile includes `FLAG_LINK_INTR`, which requires an
interrupt/status endpoint. Apple's private interfaces have no such endpoint.
Without a product-specific match, endpoint discovery fails and the kernel logs
`bind() failure`.

The upstream quirk maps both Apple Mac functions to
`apple_private_interface_info`. That profile omits `FLAG_LINK_INTR` while
retaining the NCM framing and Apple-specific zero-length-packet behaviour.

## Data path

After the driver binds and each side has an address, the path is ordinary IP:

```text
application socket
  -> IP routing
  -> Mac enX
  -> CDC-NCM NTBs over USB
  -> Linux enx...
  -> application socket
```

No bridge, default-route replacement, DNS change, or Internet Connection
Sharing is required for a point-to-point subnet.

## Boundaries

- USB negotiation speed is not application throughput.
- Interface names and ordering are not stable identifiers.
- The repository does not select a function automatically for configuration.
- The repository does not provide DHCP.
- Kernel support must be determined from the actual installed module, not only
  the kernel release string.
