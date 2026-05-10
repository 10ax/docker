Portainer deployment
====================

This directory is now the source of truth for the local Portainer deployment.

Current state
-------------

- Compose file: `compose.yaml`
- Running image: `portainer/portainer-ce:2.39.2`
- Running container name: `portainer`
- Preserved pre-upgrade container: `portainer-pre-2.27.6`
- External data volume: `portainer_data`
- Cold backup archive: `/root/docker/portainer/backups/portainer-data-pre-2.39.2-20260510-112708.tgz`

Upgrade notes
-------------

- The previous container was running from the floating tag `portainer/portainer-ce:lts`.
- Portainer performed an in-app database migration from `2.27.6` to `2.39.2` on first start.
- Portainer also created its own database backup at `/data/backups/portainer.db.bak` inside the volume.

Routine management
------------------

Start or recreate the pinned deployment:

    cd /root/docker/portainer
    docker compose up -d

Check status:

    cd /root/docker/portainer
    docker compose ps
    curl -sk https://127.0.0.1:9443/api/status

Rollback
--------

Because the database was migrated in place, a real rollback should restore the
pre-upgrade data backup before starting the old container version.

1. Stop and remove the current container:

       cd /root/docker/portainer
       docker compose down

2. Restore the backup archive into the external data volume:

       rm -rf /mnt/dietpi_userdata/docker-data/volumes/portainer_data/_data/*
       tar -C /mnt/dietpi_userdata/docker-data/volumes/portainer_data/_data -xzf /root/docker/portainer/backups/portainer-data-pre-2.39.2-20260510-112708.tgz

3. Either rename and restart the preserved old container, or update `compose.yaml`
   back to the old image and recreate it.

4. If the preserved old container is used directly:

       docker rm -f portainer 2>/dev/null || true
       docker rename portainer-pre-2.27.6 portainer
       docker start portainer

If rollback is not needed, the preserved old container can be removed later:

    docker rm portainer-pre-2.27.6