# Electrs Docker Images

This repository provides automated Docker images for Electrs.
Images are built for all official releases starting from `v0.11.0` and pushed to GitHub Container Registry (GHCR).
The workflow automatically detects new releases from `romanz/electrs` and triggers the Docker build.
The latest tag is set only for the newest official release.

Electrs provides a fast, private, and fully indexed Electrum-compatible API backed by your own Bitcoin Core node.

This image supports:

- 🚀 Fast Electrum server backed by RocksDB
- 🔑 Cookie authentication with Bitcoin Core
- 👤 Non-root runtime using PUID/PGID (Unraid compatible)
- 📁 Simple configuration using electrs.toml in the data directory
- 🔧 Clean multi-stage build
- 📊 Optional Prometheus metrics endpoint

## 📌 Features

- Multi-stage Rust build → small final image
- Dynamic user permissions via `PUID`, `PGID`, and `UMASK`
- Works with Bitcoin Core (bitcoind) running in a separate container
- Supports large full-node index databases
- Works on Unraid, Docker CLI, Docker Compose, Portainer, etc.

## 🧩 Requirements

- A running Bitcoin Core (bitcoind) container
- RPC port (8332) and P2P port (8333) must be reachable by Electrs
- A `.cookie` authentication file must be mounted into `/home/electrs/.bitcoin`
- A configuration file `/data/electrs.toml` must be provided by the user

## 🚀 Usage

Minimal example:

```
docker run -d \
  --name electrs \
  -p 50001:50001 \
  -v /mnt/user/bitcoin/electrs:/data \
  -v /mnt/user/bitcoin/bitcoind:/home/electrs/.bitcoin \
  ghcr.io/anym001/docker-electrs:<version>
```

With permissions mapping:

```
docker run -d \
  --name electrs \
  -e PUID=99 \
  -e PGID=100 \
  -e UMASK=002 \
  -p 50001:50001 \
  -v /mnt/user/bitcoin/electrs:/data \
  -v /mnt/user/bitcoin/bitcoind:/home/electrs/.bitcoin \
  ghcr.io/anym001/docker-electrs:<version>
```

Tags:

- `<version>` → e.g., 0.11.0 (always built for each release)
- `latest` → points to the latest official release

## 📁 Configuration

You must create a configuration file inside your mounted directory:

```
/your/data/dir/electrs.toml
```

Inside the container this becomes:

```
/data/electrs.toml
```

Example:

```
network = "bitcoin"
daemon_rpc_addr = "bitcoind:8332"
daemon_p2p_addr = "bitcoind:8333"
daemon_auth = "/home/electrs/.bitcoin/.cookie"
db_dir = "/data/db"
electrum_rpc_addr = "0.0.0.0:50001"
```

## 🔧 Environment Variables

| Variable | Description                                                   |
| :------- | :------------------------------------------------------------ |
| PUID     | Container user UID (maps to host UID). Optional.              |
| PGID     | Container group GID (maps to host GID). Optional.             |
| UMASK    | Default file creation mask inside the container. Default: 002 |

## 📁 Volume Mounts

| Container Path         | Purpose                                           |
| :--------------------- | :------------------------------------------------ |
| /data                  | Container user UID (maps to host UID). Optional.  |
| /home/electrs/.bitcoin | Container group GID (maps to host GID). Optional. |

## 🔌 Ports

| Port.     | Description                   |
| :-------- | :---------------------------- |
| 50001/tcp | Electrum RPC port             |
| 4224/tcp  | Prometheus metrics (optional) |

## 🔒 Security

This image is designed with safety in mind:

- Runs as non-root user electrs
- Uses minimal base image (debian:stable-slim)
- No unnecessary packages installed
- Ensures safe access to the mounted volume using:
  - PUID
  - PGID
  - UMASK

## 🏗️ Automated Build System

1. release-check.yml workflow:

   - Checks all official electrs releases
   - Determines which releases are missing in your repo
   - Triggers build-docker.yml for missing releases
   - Passes LATEST=true for the newest release

2. build-docker.yml workflow:
   - Downloads official binaries
   - Extracts required binaries
   - Builds and pushes Docker images to GHCR
   - Creates a GitHub Release for each version

## 🤝 Contributing

PRs are welcome, especially improvements to:

- Docker security hardening
- Improving automated workflows
- Enhancing testing or verification
- Image signing and supply-chain security
- Documentation
