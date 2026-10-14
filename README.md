# Docker Homelab

This repository tracks the Docker Compose stacks and selected non-sensitive configuration under `/root/docker`.

It also tracks selected host-native service files when a service has been moved out of Docker but is still part of the homelab runtime.

## Projects

- `home-assistant`: Home Assistant compose stack and core configuration.
- `matter-bridge`: Matter server compose project that uses host data in `matter-server/data`.
- `nginx-proxy-manager`: Reverse proxy and TLS termination.
- `portainer`: Portainer CE management UI.

## Git Scope

This repo is tuned for a remote Git host:

- tracked: compose files, runbooks, and non-sensitive configuration
- ignored: secrets, certificates, live databases, Matter operational data, logs, caches, and exported backups

If you need full disaster recovery, back up the ignored runtime state separately from Git.

## Validation

Validate a stack from its project root:

```sh
cd /root/docker/home-assistant
docker compose config
```