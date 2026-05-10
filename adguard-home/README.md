# AdGuard Home Setup And Rollback

This directory contains the standalone AdGuard Home deployment used for network-wide DNS blocking on the LAN.

## Why this was set up

The router does not expose a reliable LAN DHCP option to hand out a custom DNS server to all clients. Because of that limitation, the deployment was done by:

1. Running AdGuard Home on the host network.
2. Binding DNS directly to the host LAN address.
3. Enabling AdGuard's own DHCP server.
4. Disabling the router's DHCP server so LAN clients receive AdGuard-managed leases.

## Current live state

- Host LAN IP: `192.168.1.7`
- Router/gateway IP: `192.168.1.1`
- Router model used during setup: `ZTE H388XF`
- AdGuard admin UI: `http://192.168.1.7:3001`
- AdGuard DNS listener: `192.168.1.7:53`
- AdGuard DHCP listener: `0.0.0.0:67` on `eth0`
- Container name: `adguard-home`
- Compose file: `./compose.yaml`
- Persistent config: `./conf/AdGuardHome.yaml`
- Persistent working data: `./work/`

## Files changed for this setup

### `compose.yaml`

The stack was created with:

- `network_mode: host`
- `cap_add: NET_ADMIN`
- bind mounts for `./work` and `./conf`
- Docker healthcheck targeting `http://192.168.1.7:3001`

The healthcheck intentionally uses the LAN IP, not `127.0.0.1`, because AdGuard was configured to bind the web UI only to `192.168.1.7:3001`.

### `conf/AdGuardHome.yaml`

The running AdGuard configuration includes:

- web UI bound to `192.168.1.7:3001`
- DNS bound to `192.168.1.7:53`
- upstream DNS set to Quad9 DoH: `https://dns10.quad9.net/dns-query`
- DHCP enabled on interface `eth0`
- DHCP range `192.168.1.100` to `192.168.1.200`
- DHCP gateway `192.168.1.1`
- subnet mask `255.255.255.0`
- lease duration `86400` seconds
- local domain `lan`
- default AdGuard DNS filter enabled

## Setup actions that were performed

1. Verified the host uses a static LAN address of `192.168.1.7`.
2. Confirmed no other service should keep port `53` busy. `dnsmasq` was left disabled so AdGuard could own DNS.
3. Created the AdGuard Home compose stack in this directory using host networking.
4. Started the container and completed the AdGuard first-run setup.
5. Moved the permanent AdGuard web UI to port `3001` to avoid installer port conflicts.
6. Bound DNS to `192.168.1.7:53`.
7. Configured upstream DNS to Quad9 DoH.
8. Enabled AdGuard DHCP on `eth0` with the range `192.168.1.100-192.168.1.200`.
9. Checked the router UI and confirmed it could not reliably distribute a custom LAN DNS server through its normal DHCP settings.
10. Disabled the router DHCP server so AdGuard would become the single DHCP authority for the LAN.
11. Fixed the Docker healthcheck so container health reflects the real bound web UI address.
12. Validated that the container became healthy and that DNS answers resolve through `192.168.1.7`.

## Validation performed

These checks were verified after setup:

- container state: `running`
- Docker health state: `healthy`
- TCP and UDP port `53` listening on `192.168.1.7`
- UDP port `67` listening for DHCP on `eth0`
- web UI responding on `192.168.1.7:3001`
- host name resolution working while AdGuard is active
- router DHCP page showing DHCP disabled

## Operational notes

- Do not run router DHCP and AdGuard DHCP together longer than necessary. That can create split leases and random client behavior.
- The host must keep the static IP `192.168.1.7`. If that address changes, DNS and DHCP on the LAN will break until AdGuard and clients are updated.
- If clients do not pick up AdGuard immediately, renew their DHCP lease or reconnect them to the network.
- `dnsmasq` should stay disabled while AdGuard owns port `53`.

## Safe rollback options

### Option 1: Keep AdGuard DNS, give DHCP back to the router

Use this only if the router can be configured to hand out `192.168.1.7` as DNS, or if you are willing to set DNS manually on clients.

1. Log in to the router at `http://192.168.1.1`.
2. Re-enable the router DHCP server and apply the change.
3. In AdGuard, disable DHCP from the web UI, or stop the container after the router DHCP server is active.
4. Renew client DHCP leases.
5. Verify clients still use the intended DNS server.

### Option 2: Full rollback to router-managed networking

Use this to remove AdGuard from the network path completely.

1. Log in to the router at `http://192.168.1.1`.
2. Re-enable the router DHCP server and apply the change.
3. Wait until the router is ready to serve leases again.
4. Stop AdGuard DHCP by either:
   - disabling DHCP in the AdGuard web UI, or
   - stopping the stack with `docker compose down` in this directory.
5. Renew client DHCP leases or reconnect clients so they obtain router-managed settings.
6. Confirm clients receive valid IP addresses, gateway `192.168.1.1`, and working DNS.
7. If you no longer want AdGuard on the host, keep a backup of `./conf/` and `./work/`, then remove the stack.

Example commands:

```sh
cd /root/docker/adguard-home
docker compose down
tar -czf adguard-home-backup-$(date +%Y%m%d-%H%M%S).tar.gz conf work
```

### Option 3: Remove blocking but keep AdGuard running

Use this if DNS service should remain online but without filtering.

1. Open the AdGuard web UI at `http://192.168.1.7:3001`.
2. Disable protection or disable the active filter lists.
3. Leave DNS and optionally DHCP enabled.

## Restart and inspection commands

```sh
cd /root/docker/adguard-home
docker compose up -d
docker compose down
docker inspect adguard-home --format 'Status={{.State.Status}} Health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'
ss -ltnup '( sport = :53 or sport = :67 or sport = :3001 )'
```

## If rollback is needed later

Use the rollback order exactly:

1. Re-enable router DHCP first.
2. Disable AdGuard DHCP second.
3. Renew client leases.
4. Only then stop or remove the AdGuard stack.

That order avoids leaving the network with no DHCP server.