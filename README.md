# nano-bootstrap-swarm

Decentralized [Nano](https://nano.org) ledger snapshot distribution using BitTorrent BEP 46 mutable torrents and DHT.

The ledger lives as an LMDB database (~80 GB). Rather than serving it from a single S3 bucket, this system lets anyone contribute bandwidth by seeding snapshots peer-to-peer. New snapshots are published to the Mainline DHT under an Ed25519 authority key; mirrors discover updates and download only the changed pieces via BitTorrent v2 delta efficiency.

---

## Two Services

| Service | Location | Description |
|---|---|---|
| **Mirror** | `mirror/` | Docker sidecar. Discovers snapshots via DHT, downloads and seeds them. |
| **Producer** | `producer/` | CLI tool. Snapshots a live Nano node, compresses with zstd, creates a torrent, and publishes the info-hash to the DHT. |

## Two Mirror Modes

| Mode | Flag | Use Case |
|---|---|---|
| **Swarm** | (default, daemon) | Long-running mirror. Polls DHT every N seconds, auto-updates, seeds back to the P2P network. |
| **Leech** | `--once` | One-shot download. Discover latest → download → exit. Good for CI, one-off syncs, testing. |

## Quick Start

### Swarm Mode (long-running mirror)

```bash
# Build the image
docker build -f mirror/Dockerfile -t nano-bootstrap-mirror .

# Or pull the pre-built image
# docker pull ghcr.io/openrai/nano-p2p-mirror:latest

export AUTHORITY_PUBKEY=<your_authority_pubkey_hex>
docker compose up -d
docker compose logs -f
```

### Leech Mode (one-shot download)

```bash
export AUTHORITY_PUBKEY=<your_authority_pubkey_hex>
docker run --rm \
  -e AUTHORITY_PUBKEY \
  -v $(pwd)/data:/data \
  ghcr.io/openrai/nano-p2p-mirror:latest \
  --once --download-timeout 3600
# Exits 0 on success, 1 on failure
ls data/*.ldb.zst
```

---

## Documentation

| Document | What it covers |
|---|---|
| [docs/getting-started.md](docs/getting-started.md) | First Docker run, verify healthcheck |
| [docs/mirror-swarm-mode.md](docs/mirror-swarm-mode.md) | Long-running seeding mirror |
| [docs/mirror-leech-mode.md](docs/mirror-leech-mode.md) | One-shot download (--once) |
| [docs/producer-guide.md](docs/producer-guide.md) | Running the Producer, key generation, scheduling |
| [docs/configuration.md](docs/configuration.md) | All environment variables, CLI flags, docker-compose reference |
| [docs/architecture.md](docs/architecture.md) | How BEP 46, DHT, zstd --rsyncable, and delta updates work |
| [docs/validation.md](docs/validation.md) | Manual test templates |
