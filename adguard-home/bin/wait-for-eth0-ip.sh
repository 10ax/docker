#!/bin/sh
set -eu

interface="${1:-eth0}"
attempt=0
max_attempts=30

while [ "$attempt" -lt "$max_attempts" ]; do
  if ip -4 -o addr show dev "$interface" scope global | grep -q 'inet '; then
    exit 0
  fi

  attempt=$((attempt + 1))
  logger -t adguard-startup "waiting for IPv4 on $interface ($attempt/$max_attempts)"
  sleep 2
done

logger -t adguard-startup "timed out waiting for IPv4 on $interface"
exit 1