#!/bin/sh
set -eu

service_name="AdGuardHome.service"
interface="eth0"
missing=""
probe_domain="example.com"

if ! systemctl is-active --quiet "$service_name"; then
  logger -t adguard-healthcheck "$service_name is not active; restarting"
  systemctl restart "$service_name"
  exit 0
fi

if ! ip -4 -o addr show dev "$interface" scope global | grep -q 'inet '; then
  logger -t adguard-healthcheck "$interface has no IPv4 address yet; skipping health check"
  exit 0
fi

if ! ss -H -lun 'sport = :53' | grep -q ':53'; then
  missing="udp53"
fi

if ! ss -H -ltn 'sport = :53' | grep -q ':53'; then
  missing="$missing tcp53"
fi

if ! ss -H -lun 'sport = :67' | grep -q ':67'; then
  missing="$missing udp67"
fi

if [ -n "$missing" ]; then
  logger -t adguard-healthcheck "missing listeners:$missing; restarting $service_name"
  systemctl restart "$service_name"
  exit 0
fi

if ! dig +time=2 +tries=1 @127.0.0.1 "$probe_domain" +short | grep -q '^[0-9]'; then
  logger -t adguard-healthcheck "local DNS probe failed for $probe_domain; restarting $service_name"
  systemctl restart "$service_name"
fi