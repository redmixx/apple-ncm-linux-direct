# Temporary static IPv4 example

This documentation-only subnet does not alter a default route or DNS:

| Peer | Interface | Address |
| --- | --- | --- |
| Apple Silicon Mac | verified `enX` | `10.55.0.1/30` |
| Linux | verified `enx...` | `10.55.0.2/30` |

## Linux dry-run

```bash
./scripts/configure-link-linux.sh \
  --interface enx0123456789ab \
  --linux-address 10.55.0.2/30 \
  --peer-address 10.55.0.1
```

## macOS temporary alias

```bash
sudo ifconfig enX inet 10.55.0.1 netmask 255.255.255.252 alias
```

## Verification

```bash
# Linux
ip route get 10.55.0.1
ping 10.55.0.1

# macOS
route -n get 10.55.0.2
ping 10.55.0.2
```

## Removal

```bash
# Linux: dry-run first
./scripts/rollback.sh \
  --interface enx0123456789ab \
  --linux-address 10.55.0.2/30

# macOS
sudo ifconfig enX -alias 10.55.0.1
```
