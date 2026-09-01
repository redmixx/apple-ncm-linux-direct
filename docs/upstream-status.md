# Upstream status

Status checked on 2026-09-01.

## Apple private CDC-NCM support

The reusable `apple_private_interface_info` driver profile was added by Linux
commit [`3ec8d7572a69`](https://github.com/torvalds/linux/commit/3ec8d7572a69d142d49f52b28ce8d84e5fef9131).
It permits Apple's private NCM interface to operate without an interrupt/status
endpoint.

Mac product ID support then arrived separately:

| Apple VID:PID | Interfaces | Upstream commit | Release observation |
| --- | --- | --- | --- |
| `05ac:1905` | 0 and 2 | [`a5148bc2fa27`](https://github.com/torvalds/linux/commit/a5148bc2fa27092862ac4b9e7b5c8340d60cff34) | absent from v7.0, present in v7.1 |
| `05ac:1902` | 0 and 2 | [`746fc0787f61`](https://github.com/torvalds/linux/commit/746fc0787f616da418ffc04a110296fe95d53491) | absent from v7.2, present in current mainline after v7.2 |

Vendor and stable kernels can backport either change, so scripts inspect the
actual installed module aliases instead of inferring support from `uname -r`.

## Kernels that may require the `1905` patch

- Mainline v7.0 and older do not contain commit `a5148bc...` unless it was
  backported.
- Distribution kernels based on older releases may or may not contain a
  backport.
- A kernel can contain the source change while an older external module is
  installed, or vice versa.

Therefore, “may require” is the strongest safe version-only conclusion. Both
`in00` and `in02` module aliases are the operational check.

## Related work

- [`AmeerJ97/apple-ncm-1902-linux-direct-link`](https://github.com/AmeerJ97/apple-ncm-1902-linux-direct-link)
  is a separate investigation focused on PID `1902`, USB3 link power management,
  and a gated test harness. This repository does not copy its README or claim
  its hardware findings for `1905`.
- Linux upstream itself is the source of truth for accepted `cdc_ncm` changes.

## Known upstream and platform limitations

- Apple exposes two functions; interface naming and ordering are not stable.
- Product IDs can depend on Mac generation and the USB4/Thunderbolt path.
- The ID-table fix addresses binding, not every cable, controller, firmware, or
  link-power-management problem.
- Native support in mainline does not guarantee that a distribution has shipped
  the same code.
- USB bus speed is not guaranteed TCP or application throughput.
- macOS behaviour is not a stable public protocol contract for this use case.
