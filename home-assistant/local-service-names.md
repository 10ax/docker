# Local Service Names

This document covers the local hostname setup that lets LAN clients reach services by name instead of by IP and port.

## Current hostnames

- `smart.casa` -> Home Assistant
- `smart.home.arpa` -> Home Assistant
- `hass.casa` -> Home Assistant
- `hass.home.arpa` -> Home Assistant
- `guard.casa` -> AdGuard Home
- `guard.home.arpa` -> AdGuard Home
- `portainer.casa` -> Portainer
- `portainer.home.arpa` -> Portainer
- `matter.casa` -> Matter Server
- `matter.home.arpa` -> Matter Server

These names resolve to the host LAN IP `192.168.1.7` through AdGuard Home. A reverse proxy on the same host then routes traffic by hostname:

- `smart.casa` proxies to Home Assistant on `192.168.1.7:8123`
- `smart.home.arpa` proxies to Home Assistant on `192.168.1.7:8123`
- `hass.casa` proxies to Home Assistant on `192.168.1.7:8123`
- `hass.home.arpa` proxies to Home Assistant on `192.168.1.7:8123`
- `guard.casa` proxies to AdGuard Home on `192.168.1.7:3001`
- `guard.home.arpa` proxies to AdGuard Home on `192.168.1.7:3001`
- `portainer.casa` proxies to Portainer on `192.168.1.7:9443`
- `portainer.home.arpa` proxies to Portainer on `192.168.1.7:9443`
- `matter.casa` proxies to Matter Server on `192.168.1.7:5580`
- `matter.home.arpa` proxies to Matter Server on `192.168.1.7:5580`

## Components involved

1. AdGuard Home provides LAN DNS resolution.
2. Nginx Proxy Manager listens on ports `80` and `443` on the host.
3. A locally generated certificate from `mkcert` is used for HTTPS.
4. Home Assistant is configured to trust the reverse proxy subnet.

No new reverse proxy software was installed because Nginx Proxy Manager was already running on the host. `mkcert` was already available and was used to create the local CA and certificate for the `.casa` names.

## Files changed

### Home Assistant

File: `config/configuration.yaml`

Added:

- `http.use_x_forwarded_for: true`
- `http.trusted_proxies: [172.20.0.0/16]`

This allows Home Assistant to accept requests forwarded by the existing Nginx Proxy Manager container on the `nginx-proxy-manager_default` Docker network.

### AdGuard Home

File: `adguard-home/conf/AdGuardHome.yaml`

Added enabled DNS rewrites:

- `smart.casa -> 192.168.1.7`
- `smart.home.arpa -> 192.168.1.7`
- `hass.casa -> 192.168.1.7`
- `hass.home.arpa -> 192.168.1.7`
- `guard.casa -> 192.168.1.7`
- `guard.home.arpa -> 192.168.1.7`
- `portainer.casa -> 192.168.1.7`
- `portainer.home.arpa -> 192.168.1.7`
- `matter.casa -> 192.168.1.7`
- `matter.home.arpa -> 192.168.1.7`

These names only resolve for clients that use AdGuard Home as DNS.

### Reverse proxy

File on host outside this workspace:

- `/root/docker/nginx-proxy-manager/data/nginx/custom/http.conf`

The custom nginx file now contains:

- an HTTP redirect from port `80` to `https://$host$request_uri`
- a TLS server for `smart.casa` and `hass.casa` -> `192.168.1.7:8123`
- a TLS server for `guard.casa` -> `192.168.1.7:3001`
- a TLS server for `portainer.casa` -> `192.168.1.7:9443`
- a TLS server for `matter.casa` -> `192.168.1.7:5580`

The Home Assistant and Portainer routes also set websocket upgrade headers and longer proxy timeouts.

### Local TLS files

Public root CA certificate for client trust:

- `local-certs/casa-rootCA.pem`

Private CA material on the host, outside the workspace:

- `/root/.local/share/mkcert-home-lan/`

Reverse proxy leaf certificate and key used by nginx, outside the workspace:

- `/root/docker/nginx-proxy-manager/data/custom_ssl/casa-local.pem`
- `/root/docker/nginx-proxy-manager/data/custom_ssl/casa-local-key.pem`

## Changes applied

1. Updated Home Assistant config to trust the reverse proxy subnet.
2. Validated Home Assistant config with `python -m homeassistant --script check_config --config /config` inside the running container.
3. Created a persistent local CA with `mkcert`.
4. Generated one SAN certificate covering `smart.casa`, `hass.casa`, `guard.casa`, `portainer.casa`, and `matter.casa`.
5. Copied the public root CA certificate into `local-certs/casa-rootCA.pem` for device trust.
6. Added local DNS rewrites to AdGuard Home.
7. Replaced the HTTP-only nginx host rules with HTTP-to-HTTPS redirect and TLS virtual hosts.
8. Reloaded Nginx Proxy Manager.
9. Restarted AdGuard Home.
10. Kept Home Assistant on the existing trusted proxy subnet configuration.
11. Added parallel `.home.arpa` aliases for the same services to avoid public-TLD ambiguity on some clients.
12. Regenerated the same certificate to include both the `.casa` names and the `.home.arpa` aliases.

## Validation performed

The following checks were verified:

- `nslookup -type=A smart.casa 192.168.1.7` returned `192.168.1.7`.
- `nslookup -type=A smart.home.arpa 192.168.1.7` returned `192.168.1.7`.
- `nslookup -type=A hass.casa 192.168.1.7` returned `192.168.1.7`.
- `nslookup -type=A hass.home.arpa 192.168.1.7` returned `192.168.1.7`.
- `nslookup -type=A guard.casa 192.168.1.7` returned `192.168.1.7`.
- `nslookup -type=A guard.home.arpa 192.168.1.7` returned `192.168.1.7`.
- `nslookup -type=A portainer.casa 192.168.1.7` returned `192.168.1.7`.
- `nslookup -type=A portainer.home.arpa 192.168.1.7` returned `192.168.1.7`.
- `nslookup -type=A matter.casa 192.168.1.7` returned `192.168.1.7`.
- `nslookup -type=A matter.home.arpa 192.168.1.7` returned `192.168.1.7`.
- `curl -I --resolve smart.casa:80:127.0.0.1 http://smart.casa/` returned a `301` redirect to `https://smart.casa/`.
- `curl --cacert local-certs/casa-rootCA.pem --resolve smart.casa:443:127.0.0.1 https://smart.casa/` returned Home Assistant content.
- `curl --cacert local-certs/casa-rootCA.pem --resolve hass.casa:443:127.0.0.1 https://hass.casa/` returned Home Assistant content.
- `curl --cacert local-certs/casa-rootCA.pem --resolve guard.casa:443:127.0.0.1 -I https://guard.casa/` returned the AdGuard login redirect.
- `curl --cacert local-certs/casa-rootCA.pem --resolve portainer.casa:443:127.0.0.1 -I https://portainer.casa/` returned a successful Portainer response.
- `curl --cacert local-certs/casa-rootCA.pem --resolve matter.casa:443:127.0.0.1 https://matter.casa/` returned Matter Server HTML.

## Operational notes

- These names are local-only. They work only for clients using AdGuard Home as DNS.
- The setup now serves these hostnames over HTTPS on the LAN reverse proxy.
- Browsers and apps will trust the HTTPS connection only after the local root CA in `local-certs/casa-rootCA.pem` is installed on that device.
- If a device does not trust the local CA, it will show a certificate warning until that CA is installed.
- `.home.arpa` is the reserved home-network namespace and is the safer choice when a client behaves badly with `.casa`, which is a real public TLD.

For platform-specific certificate installation steps, see [local-certs/README.md](/root/docker/home-assistant/local-certs/README.md).

## Routine maintenance

### Check the current certificate and hostname list

Inspect the currently issued certificate and SANs:

```sh
openssl x509 -in /root/docker/nginx-proxy-manager/data/custom_ssl/casa-local.pem -noout -dates -ext subjectAltName
```

Inspect the current DNS rewrites:

```sh
grep -n -A20 '^  rewrites:' /root/docker/adguard-home/conf/AdGuardHome.yaml
```

Inspect the current reverse-proxy rules:

```sh
sed -n '1,260p' /root/docker/nginx-proxy-manager/data/nginx/custom/http.conf
```

### Validate after any change

Validate the nginx config before reload:

```sh
docker exec nginx-proxy-manager-app-1 nginx -t
```

Reload nginx after a successful config test:

```sh
docker exec nginx-proxy-manager-app-1 nginx -s reload
```

Restart AdGuard Home after changing DNS rewrites:

```sh
docker restart adguard-home
```

Re-check DNS and HTTPS end to end:

```sh
nslookup -type=A smart.casa 192.168.1.7
curl --cacert /root/docker/home-assistant/local-certs/casa-rootCA.pem https://smart.casa
```

## Add a new local name

Use this sequence whenever you add another hostname such as `newthing.casa`.

1. Decide which backend it should reach and whether it is only an alias of an existing service or a new proxied service.
2. Add a new enabled rewrite entry under `filtering.rewrites` in [AdGuardHome.yaml](/root/docker/adguard-home/conf/AdGuardHome.yaml).
3. Update `/root/docker/nginx-proxy-manager/data/nginx/custom/http.conf`.
4. If the new hostname points to an existing service, you can often just add it to an existing `server_name` line.
5. If it points to a new backend, add a new `server` block with the correct upstream host, port, and any websocket or timeout settings it needs.
6. Regenerate the certificate with the full hostname list. `mkcert` replaces the SAN list; it does not append automatically.
7. Validate nginx, reload nginx, and restart AdGuard Home.
8. Test DNS resolution and HTTPS reachability.

Example certificate regeneration when adding `newthing.casa`:

```sh
CAROOT=/root/.local/share/mkcert-home-lan mkcert \
	-cert-file /root/docker/nginx-proxy-manager/data/custom_ssl/casa-local.pem \
	-key-file /root/docker/nginx-proxy-manager/data/custom_ssl/casa-local-key.pem \
	smart.casa hass.casa guard.casa portainer.casa matter.casa newthing.casa

docker exec nginx-proxy-manager-app-1 nginx -t
docker exec nginx-proxy-manager-app-1 nginx -s reload
docker restart adguard-home
```

### When you do not need to regenerate the certificate

You only avoid certificate regeneration if the hostname is already covered by the existing certificate.

If the hostname is new, regenerate the certificate.

## Change the backend for an existing name

If you keep the same hostname and only move it to a different local service:

1. Leave the AdGuard rewrite unchanged if the hostname should still resolve to `192.168.1.7`.
2. Edit the matching nginx `server` block and update `$server`, `$port`, and `$forward_scheme` if needed.
3. Validate and reload nginx.
4. Test with `curl --cacert /root/docker/home-assistant/local-certs/casa-rootCA.pem https://thatname.casa`.

## Rotate or renew the certificate

The current certificate is locally issued by `mkcert`, so rotation is just another certificate generation using the same CA.

Use this when:

- you add names
- you remove names
- you want a fresh validity period
- you want to replace the leaf keypair

Regenerate the leaf certificate with the full hostname list, then reload nginx:

```sh
CAROOT=/root/.local/share/mkcert-home-lan mkcert \
	-cert-file /root/docker/nginx-proxy-manager/data/custom_ssl/casa-local.pem \
	-key-file /root/docker/nginx-proxy-manager/data/custom_ssl/casa-local-key.pem \
	smart.casa hass.casa guard.casa portainer.casa matter.casa

docker exec nginx-proxy-manager-app-1 nginx -t
docker exec nginx-proxy-manager-app-1 nginx -s reload
```

## Safe rollback

Use this order so clients do not keep resolving names to a host that no longer routes them.

1. Remove or disable the custom nginx server blocks in `/root/docker/nginx-proxy-manager/data/nginx/custom/http.conf`.
2. Reload Nginx Proxy Manager.
3. Remove the `smart.casa`, `hass.casa`, `guard.casa`, `portainer.casa`, and `matter.casa` rewrite entries from `adguard-home/conf/AdGuardHome.yaml`.
4. Remove the parallel `.home.arpa` rewrite entries if you no longer want those aliases.
5. Restart AdGuard Home.
6. If Home Assistant no longer needs any reverse proxy, remove the `http` section from `config/configuration.yaml`.
7. Restart Home Assistant.
8. If you want to fully retire the local CA later, remove the copied public CA file from `local-certs/casa-rootCA.pem` and uninstall the CA from client devices.
9. Clear browser DNS cache or renew client networking if a device keeps using stale results.

## Rollback commands

### Reload Proxy Manager after editing its custom config

```sh
docker exec nginx-proxy-manager-app-1 nginx -t
docker exec nginx-proxy-manager-app-1 nginx -s reload
```

### Restart AdGuard Home

```sh
docker restart adguard-home
```

### Restart Home Assistant

```sh
cd /root/docker/home-assistant
docker restart home-assistant
```

## Regenerating the HTTPS certificate later

If you add more local hostnames in the future, regenerate the certificate with the new names and reload nginx.

```sh
CAROOT=/root/.local/share/mkcert-home-lan mkcert \
	-cert-file /root/docker/nginx-proxy-manager/data/custom_ssl/casa-local.pem \
	-key-file /root/docker/nginx-proxy-manager/data/custom_ssl/casa-local-key.pem \
	smart.casa hass.casa guard.casa portainer.casa matter.casa \
	smart.home.arpa hass.home.arpa guard.home.arpa portainer.home.arpa matter.home.arpa

docker exec nginx-proxy-manager-app-1 nginx -t
docker exec nginx-proxy-manager-app-1 nginx -s reload
```