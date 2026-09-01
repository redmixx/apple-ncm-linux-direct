#!/usr/bin/env bash
set -u

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
target_products=(1905 1902)
found=false
found_product=""
usb_speed="UNKNOWN"
cdc_support="UNKNOWN"
patch_required="UNKNOWN"
network_interfaces=()
secure_boot="UNKNOWN"
sig_enforcement="UNKNOWN"
bind_failure="NOT OBSERVED"

echo "== System =="
printf 'Kernel: %s\n' "$(uname -r)"
uname -a

echo
echo "== USB devices =="
if command -v lsusb >/dev/null 2>&1; then
  lsusb || true
else
  echo "lsusb is not installed"
fi

echo
echo "== USB topology =="
if command -v lsusb >/dev/null 2>&1; then
  lsusb -t || true
else
  echo "lsusb is not installed"
fi

for vendor_file in /sys/bus/usb/devices/*/idVendor; do
  [[ -r $vendor_file ]] || continue
  device_dir=${vendor_file%/idVendor}
  vendor=$(tr '[:upper:]' '[:lower:]' <"$vendor_file")
  [[ $vendor == 05ac ]] || continue
  [[ -r $device_dir/idProduct ]] || continue
  product=$(tr '[:upper:]' '[:lower:]' <"$device_dir/idProduct")
  for candidate in "${target_products[@]}"; do
    if [[ $product == "$candidate" ]]; then
      found=true
      found_product=$product
      if [[ -r $device_dir/speed ]]; then
        usb_speed=$(<"$device_dir/speed")
        usb_speed="${usb_speed}M"
      fi
      break 2
    fi
  done
done

if ! $found && command -v lsusb >/dev/null 2>&1; then
  lsusb_text=$(lsusb 2>/dev/null || true)
  for candidate in "${target_products[@]}"; do
    if grep -Eiq "05ac:${candidate}" <<<"$lsusb_text"; then
      found=true
      found_product=$candidate
      break
    fi
  done
fi

echo
echo "== cdc_ncm metadata =="
if command -v modinfo >/dev/null 2>&1 && modinfo cdc_ncm >/dev/null 2>&1; then
  modinfo cdc_ncm | grep -E '^(filename|version|license|description|alias|depends|signer|sig_key|sig_hashalgo|vermagic):' || true
  if [[ -n $found_product ]]; then
    if "$script_dir/check-kernel-support.sh" --product "$found_product" >/dev/null 2>&1; then
      cdc_support="PRESENT"
      patch_required="NO"
    else
      check_rc=$?
      if [[ $check_rc -eq 2 ]]; then
        cdc_support="MISSING OR INCOMPLETE"
        patch_required="YES"
      fi
    fi
  else
    cdc_support="MODULE AVAILABLE; DEVICE NOT FOUND"
  fi
else
  echo "modinfo could not inspect cdc_ncm"
fi

echo
echo "== Relevant kernel messages =="
if dmesg_output=$(dmesg 2>/dev/null); then
  relevant=$(grep -Ei 'cdc_ncm|05ac|1905|1902|bind\(\) failure|SuperSpeed' <<<"$dmesg_output" | tail -80 || true)
  if [[ -n $relevant ]]; then
    printf '%s\n' "$relevant"
  else
    echo "No relevant messages found in the readable dmesg buffer"
  fi
  if grep -Eqi 'cdc_ncm.*bind\(\) failure' <<<"$relevant"; then
    bind_failure="OBSERVED"
  fi
else
  echo "dmesg is not readable by this user; no privilege escalation attempted"
fi

echo
echo "== Network links =="
if command -v ip >/dev/null 2>&1; then
  ip -br link || true
  echo
  ip -br addr || true
else
  echo "ip is not installed"
fi

for net_path in /sys/class/net/*; do
  [[ -e $net_path ]] || continue
  driver_link=$net_path/device/driver
  [[ -L $driver_link ]] || continue
  driver=$(basename "$(readlink -f "$driver_link")")
  if [[ $driver == cdc_ncm ]]; then
    network_interfaces+=("$(basename "$net_path")")
  fi
done

echo
echo "== Secure Boot and module signing =="
if command -v mokutil >/dev/null 2>&1; then
  secure_boot=$(mokutil --sb-state 2>/dev/null | head -1 || true)
  [[ -n $secure_boot ]] || secure_boot="UNKNOWN"
  printf '%s\n' "$secure_boot"
else
  echo "mokutil is not installed"
fi

if [[ -r /sys/module/module/parameters/sig_enforce ]]; then
  sig_enforcement=$(</sys/module/module/parameters/sig_enforce)
elif [[ -r /boot/config-$(uname -r) ]]; then
  if grep -q '^CONFIG_MODULE_SIG_FORCE=y' "/boot/config-$(uname -r)"; then
    sig_enforcement="Y"
  else
    sig_enforcement="N OR RUNTIME-DEPENDENT"
  fi
fi
printf 'Module signature enforcement: %s\n' "$sig_enforcement"

if ! $found; then
  next_step="Check cable orientation/capability and confirm the Mac is exposing USB networking."
elif [[ $usb_speed == 480M ]]; then
  next_step="Replace the cable or port with a USB 3.x data-capable connection."
elif [[ $patch_required == YES ]]; then
  next_step="Obtain exact matching kernel source, then use build-cdc-ncm.sh; do not load anything yet."
elif ((${#network_interfaces[@]} == 0)); then
  next_step="Inspect the relevant dmesg lines and confirm which driver owns interfaces 0 and 2."
else
  next_step="Select one cdc_ncm interface and configure a temporary point-to-point IPv4 link."
fi

echo
echo "== Summary =="
if $found; then
  echo "APPLE DEVICE: FOUND (05ac:$found_product)"
else
  echo "APPLE DEVICE: NOT FOUND"
fi
echo "USB SPEED: $usb_speed"
echo "CDC_NCM SUPPORT: $cdc_support"
echo "PATCH REQUIRED: $patch_required"
if ((${#network_interfaces[@]})); then
  printf 'NETWORK INTERFACE: %s\n' "${network_interfaces[*]}"
else
  echo "NETWORK INTERFACE: NONE FOUND"
fi
echo "BIND FAILURE: $bind_failure"
echo "SECURE BOOT: $secure_boot"
echo "SIGNATURE ENFORCEMENT: $sig_enforcement"
echo "NEXT STEP: $next_step"
