#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$script_dir/.." && pwd)

echo "== Bash syntax =="
for script in "$repo_dir"/scripts/*.sh; do
  bash -n "$script"
  echo "PASS: ${script#"$repo_dir"/}"
done

echo
echo "== ShellCheck =="
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$repo_dir"/scripts/*.sh
  echo "PASS"
else
  echo "SKIP: shellcheck is not installed"
fi

echo
echo "== Patch shape =="
grep -q 'USB_DEVICE_INTERFACE_NUMBER(0x05ac, 0x1905, 0)' \
  "$repo_dir/patches/apple-mac-05ac-1905.patch"
grep -q 'USB_DEVICE_INTERFACE_NUMBER(0x05ac, 0x1905, 2)' \
  "$repo_dir/patches/apple-mac-05ac-1905.patch"
if grep -q 'USB_DEVICE_INTERFACE_NUMBER(0x05ac, 0x1902' \
  "$repo_dir/patches/apple-mac-05ac-1905.patch"; then
  echo "FAIL: the 1905 patch unexpectedly includes 1902" >&2
  exit 1
fi
echo "PASS: exactly scoped to 05ac:1905 interfaces 0 and 2"

echo
echo "== Relative Markdown links =="
python3 - "$repo_dir" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1]).resolve()
errors = []
for path in root.rglob('*.md'):
    text = path.read_text(encoding='utf-8')
    for match in re.finditer(r'(?<!!)\[[^]]+\]\(([^)]+)\)', text):
        target = match.group(1).strip()
        if target.startswith(('http://', 'https://', 'mailto:', '#')):
            continue
        target = target.split('#', 1)[0]
        if not target:
            continue
        resolved = (path.parent / target).resolve()
        try:
            resolved.relative_to(root)
        except ValueError:
            errors.append(f'{path.relative_to(root)}: link escapes repository: {target}')
            continue
        if not resolved.exists():
            errors.append(f'{path.relative_to(root)}: missing link target: {target}')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    raise SystemExit(1)
print('PASS')
PY

echo
echo "== Sensitive artifact guard =="
if find "$repo_dir" -path "$repo_dir/.git" -prune -o -type f \
  \( -name 'MOK.priv' -o -name '*.key' -o -name '*.p12' -o -name '*.pfx' \) \
  -print | grep -q .; then
  echo "FAIL: a private-key-shaped file exists in the repository" >&2
  exit 1
fi

if grep -RIl --exclude-dir=.git --exclude='verify-repo.sh' \
  -- '-----BEGIN .*PRIVATE KEY-----' "$repo_dir" | grep -q .; then
  echo "FAIL: private key material detected" >&2
  exit 1
fi

if grep -RIE --exclude-dir=.git --exclude='verify-repo.sh' \
  '(/Users/|/home/[[:alnum:]_.-]+/|192\.168\.[0-9]{1,3}\.[0-9]{1,3})' \
  "$repo_dir"; then
  echo "FAIL: local path or private LAN address detected" >&2
  exit 1
fi
echo "PASS"

echo
echo "Repository verification complete."
