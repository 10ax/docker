#!/bin/sh
set -eu

if [ "${1:-}" != "--router-dhcp-confirmed" ]; then
  echo "Refusing to disable AdGuard DHCP without --router-dhcp-confirmed" >&2
  exit 64
fi

config="/opt/AdGuardHome/AdGuardHome.yaml"
backup="${config}.backup-$(date +%Y%m%d-%H%M%S)"
tmp="$(mktemp)"

cleanup() {
  rm -f "$tmp"
}

trap cleanup EXIT

cp "$config" "$backup"

awk '
/^dhcp:$/ {
  in_dhcp = 1
  print
  next
}
in_dhcp && /^filtering:$/ {
  in_dhcp = 0
}
in_dhcp && /^  enabled: / {
  sub(/true/, "false")
}
{
  print
}
' "$config" > "$tmp"

mv "$tmp" "$config"
systemctl restart AdGuardHome.service

if ! systemctl is-active --quiet AdGuardHome.service; then
  cp "$backup" "$config"
  systemctl restart AdGuardHome.service
  echo "AdGuard failed to restart after disabling DHCP; restored $backup" >&2
  exit 1
fi

if ss -H -lun 'sport = :67' | grep -q ':67'; then
  cp "$backup" "$config"
  systemctl restart AdGuardHome.service
  echo "AdGuard is still listening on UDP 67; restored $backup" >&2
  exit 1
fi

if ! ss -H -lun 'sport = :53' | grep -q ':53'; then
  cp "$backup" "$config"
  systemctl restart AdGuardHome.service
  echo "AdGuard DNS listener disappeared; restored $backup" >&2
  exit 1
fi

echo "AdGuard DHCP disabled successfully. Verify the router is serving leases and clients still use 192.168.1.7 for DNS if desired."