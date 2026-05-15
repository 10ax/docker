#!/bin/sh
set -eu

leases="/opt/AdGuardHome/data/leases.json"
querylog="/opt/AdGuardHome/data/querylog.json"
target="${1:-lgwebostv}"
apple_pattern='apple|icloud|itunes|mzstatic|push|airport|airplay|raop|homekit|apple-dns'
lg_pattern='lgtv|lge|lgthinq|lgtvcommon|nextlgsdp|ottera|webos'

fail() {
  printf 'FAIL %s\n' "$1" >&2
}

pass() {
  printf 'PASS %s\n' "$1"
}

info() {
  printf 'INFO %s\n' "$1"
}

if [ ! -r "$leases" ]; then
  fail "missing leases file at $leases"
  exit 2
fi

if [ ! -r "$querylog" ]; then
  fail "missing query log at $querylog"
  exit 2
fi

case "$target" in
  *.*.*.*)
    client_ip="$target"
    ;;
  *)
    client_ip="$(tr '{' '\n' < "$leases" | grep -F "\"hostname\":\"$target\"" | sed -n 's/.*"ip":"\([^"]*\)".*/\1/p' | head -n 1 || true)"
    ;;
esac

if [ -z "$client_ip" ]; then
  fail "could not resolve client '$target' from $leases"
  exit 2
fi

apple_blocks="$(grep -F "\"IP\":\"$client_ip\"" "$querylog" | grep '"Reason":3' | sed -n 's/.*"QH":"\([^"]*\)".*/\1/p' | grep -Ei "$apple_pattern" | sort | uniq -c | sort -nr || true)"

if [ -n "$apple_blocks" ]; then
  fail "blocked Apple or AirPlay-related DNS domains found for $target ($client_ip)"
  printf '%s\n' "$apple_blocks"
  info "AirPlay discovery uses mDNS on the LAN, so DNS is only one part of the path."
  exit 1
fi

pass "no blocked Apple or AirPlay-related DNS domains found for $target ($client_ip)"

lg_blocks="$(grep -F "\"IP\":\"$client_ip\"" "$querylog" | grep '"Reason":3' | sed -n 's/.*"QH":"\([^"]*\)".*/\1/p' | grep -Ei "$lg_pattern" | sort | uniq -c | sort -nr || true)"

if [ -n "$lg_blocks" ]; then
  info "blocked LG domains for $target ($client_ip):"
  printf '%s\n' "$lg_blocks" | head -n 10
fi

info "AirPlay discovery uses mDNS on the LAN, so DNS logs alone do not prove the root cause."