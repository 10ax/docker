# AdGuard Home Native Service

This directory mirrors the live AdGuard Home deployment that now runs as a native systemd service on the host.

## Live runtime path

- binary: `/opt/AdGuardHome/AdGuardHome`
- live config: `/opt/AdGuardHome/AdGuardHome.yaml`
- live data: `/opt/AdGuardHome/data/`
- service unit: `/etc/systemd/system/AdGuardHome.service`
- healthcheck unit: `/etc/systemd/system/adguard-healthcheck.service`
- healthcheck timer: `/etc/systemd/system/adguard-healthcheck.timer`

The files in this repo are the version-controlled mirror of that native setup.

## Current live state

- host LAN IP: `192.168.1.7`
- router or gateway IP: `192.168.1.1`
- router model used during setup: `ZTE H388XF`
- AdGuard web UI: `http://192.168.1.7:3001`
- DNS listener: `0.0.0.0:53`
- DHCP listener: `0.0.0.0:67` on `eth0`
- service manager: `systemd`
- repo mirror config: `./conf/AdGuardHome.yaml`
- repo mirror units: `./systemd/`
- repo mirror helper scripts: `./bin/`

## What changed after the outage

The DHCP outage investigation showed that the live service was no longer the Docker stack in this directory. The actual runtime was a native AdGuard service under `/opt/AdGuardHome`, so the repo documentation and config had drifted away from the host.

The host now includes two resilience additions:

1. `AdGuardHome.service` waits for `eth0` to have an IPv4 address before start.
2. `adguard-healthcheck.timer` verifies that AdGuard is still listening on DNS `53` and DHCP `67` after boot and during runtime.
3. The healthcheck now performs a real local DNS query against `127.0.0.1` and restarts AdGuard if the process is bound but not answering.

Those files are mirrored in this directory.

## Repo mirror contents

### `conf/AdGuardHome.yaml`

Mirror of the current live AdGuard configuration.

### `systemd/`

Tracked copy of the active native units:

- `AdGuardHome.service`
- `adguard-healthcheck.service`
- `adguard-healthcheck.timer`

### `bin/`

Tracked copy of the active helper scripts:

- `wait-for-eth0-ip.sh`
- `check-adguard-health.sh`
- `check-local-service-routing.sh`
- `check-airplay-dns-blocks.sh`
- `disable-dhcp-after-router.sh`

## Validation commands

Check the live service state:

```sh
systemctl status AdGuardHome.service --no-pager
systemctl status adguard-healthcheck.timer --no-pager
```

Check the critical listeners:

```sh
ss -H -ltnup '( sport = :53 or sport = :67 or sport = :3001 )'
```

Run the quick routing regression checks:

```sh
./bin/check-local-service-routing.sh
./bin/check-airplay-dns-blocks.sh lgwebostv
```

Check recent service logs:

```sh
journalctl -u AdGuardHome.service -n 100 --no-pager
journalctl -u adguard-healthcheck.service -n 50 --no-pager
```

## Moving DHCP back to the router

The resilient target design is:

- router provides DHCP
- AdGuard provides DNS only

That handoff cannot be fully automated from this host because the router UI at `http://192.168.1.1` is authenticated and not accessible here without router credentials.

### Safe handoff order

1. Log in to the router and re-enable router DHCP.
2. Configure the router to hand out `192.168.1.7` as DNS if the router supports custom DHCP DNS.
3. After router DHCP is confirmed active, run:

```sh
sudo /usr/local/sbin/adguard-disable-dhcp.sh --router-dhcp-confirmed
```

4. Renew client DHCP leases or reconnect clients.
5. Confirm the router is serving leases and AdGuard is still answering on port `53`.

### Why the guard flag exists

The disable script refuses to run unless `--router-dhcp-confirmed` is passed. That is deliberate. Running it too early would leave the LAN without any DHCP server.

## Legacy Docker files

`compose.yaml` is kept as a historical reference for the earlier containerized setup. It is not the active runtime path for AdGuard on this host.