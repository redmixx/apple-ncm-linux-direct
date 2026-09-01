# Patch attribution and licensing

`apple-mac-05ac-1905.patch` is the ID-table change from Linux upstream commit
[`a5148bc2fa27092862ac4b9e7b5c8340d60cff34`](https://github.com/torvalds/linux/commit/a5148bc2fa27092862ac4b9e7b5c8340d60cff34),
authored by Alex Cheema and committed by Jakub Kicinski.

Linux `drivers/net/usb/cdc_ncm.c` explicitly offers a choice of GPL version 2
or the 2-clause BSD license. This derivative patch is distributed under the same
`GPL-2.0-only OR BSD-2-Clause` choice. The repository's original scripts and
documentation remain MIT-licensed.

The patch adds only Apple VID:PID `05ac:1905`, interface numbers 0 and 2, using
the existing `apple_private_interface_info`. It intentionally contains no
`1902` change; that PID has its own later upstream commit
[`746fc0787f61`](https://github.com/torvalds/linux/commit/746fc0787f616da418ffc04a110296fe95d53491).
