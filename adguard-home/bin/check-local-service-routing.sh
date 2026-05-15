#!/bin/sh
set -eu

expected_ip="192.168.1.7"
expected_ui="0.0.0.0:3001"
config="/opt/AdGuardHome/AdGuardHome.yaml"
domain="portainer.home.arpa"
rewrite_domains="portainer.home.arpa smart.home.arpa"
failures=0

pass() {
  printf 'PASS %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  failures=$((failures + 1))
}

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "found command $1"
  else
    fail "missing command $1"
  fi
}

check_rewrite() {
  domain_name="$1"
  answer="$(dig +time=2 +tries=1 @127.0.0.1 "$domain_name" A +short | tail -n 1 || true)"

  if [ "$answer" = "$expected_ip" ]; then
    pass "AdGuard rewrite $domain_name -> $answer"
  else
    fail "AdGuard rewrite $domain_name expected $expected_ip, got ${answer:-<none>}"
  fi
}

require_command dig
require_command curl
require_command ss
require_command getent

if [ -r "$config" ]; then
  ui_address="$(sed -n 's/^  address: //p' "$config" | head -n 1)"
  if [ "$ui_address" = "$expected_ui" ]; then
    pass "AdGuard UI address $ui_address"
  else
    fail "AdGuard UI address expected $expected_ui, got ${ui_address:-<none>}"
  fi
else
  fail "missing AdGuard config at $config"
fi

for rewrite_domain in $rewrite_domains; do
  check_rewrite "$rewrite_domain"
done

resolved_ip="$(getent ahosts "$domain" 2>/dev/null | awk 'NR == 1 { print $1; exit }' || true)"
if [ "$resolved_ip" = "$expected_ip" ]; then
  pass "system resolver $domain -> $resolved_ip"
else
  fail "system resolver $domain expected $expected_ip, got ${resolved_ip:-<none>}"
fi

if ss -H -ltn | grep -Eq ':3001[[:space:]]'; then
  pass "AdGuard UI listener on 3001"
else
  fail "missing listener on 3001"
fi

if ss -H -ltn | grep -Eq ':443[[:space:]]'; then
  pass "reverse proxy listener on 443"
else
  fail "missing listener on 443"
fi

redirect_headers="$(curl -sSI --connect-timeout 5 --resolve "$domain:80:127.0.0.1" "http://$domain/" || true)"
if printf '%s\n' "$redirect_headers" | grep -q '^HTTP/.* 301'; then
  pass "HTTP redirect for $domain"
else
  fail "missing HTTP redirect for $domain"
fi

tls_headers="$(curl -sSI --connect-timeout 5 --resolve "$domain:443:127.0.0.1" "https://$domain/" || true)"
if printf '%s\n' "$tls_headers" | grep -q '^HTTP/.* 200'; then
  pass "HTTPS response for $domain"
else
  status_line="$(printf '%s\n' "$tls_headers" | sed -n '1p')"
  fail "unexpected HTTPS response for $domain: ${status_line:-<none>}"
fi

if [ "$failures" -eq 0 ]; then
  pass "local service routing is healthy"
  exit 0
fi

exit 1