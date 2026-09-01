# macOS setup

macOS provides the device side of the link. No third-party macOS driver is
required in the tested configuration.

## Inspect the Mac

```bash
sw_vers
system_profiler SPHardwareDataType
system_profiler SPUSBDataType
system_profiler SPThunderboltDataType
networksetup -listallhardwareports
ifconfig -a
```

Look for a newly created interface associated with
`AppleUSBDeviceNCMPrivateEthernetInterface`. Its BSD name is normally `enX`, but
the number is machine-dependent and can change.

Compare the command output before and after connecting the cable. Do not assume
that a pre-existing `enX` is the USB link.

## Add a temporary address

Replace `enX` with the verified interface:

```bash
sudo ifconfig enX inet 10.55.0.1 netmask 255.255.255.252 alias
ifconfig enX
route -n get 10.55.0.2
```

The `alias` form adds the test address without changing the default route or
DNS. Remove only that address after the test:

```bash
sudo ifconfig enX -alias 10.55.0.1
```

If the interface is managed as a macOS network service, use System Settings or
`networksetup` deliberately instead. Record the previous service configuration
before changing it.

## Verify the route

```bash
ping 10.55.0.2
route -n get 10.55.0.2
```

The route output must name the USB-NCM interface. If it names Wi-Fi or Ethernet,
stop and correct the addressing before benchmarking.

## macOS limitations

- Apple does not promise stable BSD interface numbering.
- Two NCM functions may appear.
- The displayed link media may not expose all USB bus details; confirm the
  negotiated speed on Linux as well.
- Behaviour can change between macOS releases and Mac families.
