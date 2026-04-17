# AGENTS.md

## Project: Nano P2P Ledger Snapshot Service

Decentralized Nano block-lattice distribution using BitTorrent BEP 46 (Mutable Torrents) with binary delta efficiency.

### Quick Start

```bash
# Install dependencies (producer development)
pip install pynacl bencodepy libtorrent pytest ruff

# Run tests
PYTHONPATH=$(pwd) pytest tests/ -v

# Lint
ruff check shared/ producer/ mirror/ tests/
```

### Architecture

```
shared/nano_identity.py   — Ed25519 key handling, Nano address derivation, BEP 46 target ID
shared/bep46.py            — BEP 46 signature buffer, sign/verify, DHT value encoding
producer/snapshot.sh       — mdb_copy + zstd --rsyncable pipeline
producer/torrent_create.py — BitTorrent v2 .torrent generation via libtorrent
producer/publish.py        — BEP 46 DHT mutable item publisher
producer/cli.py            — Unified CLI entry point (snapshot/publish/full)
mirror/Dockerfile           — Alpine + libtorrent build
mirror/libtorrent_session.py — libtorrent session management wrapper
mirror/dht_discovery.py    — DHT mutable item retrieval with retry/verification
mirror/watcher.py           — Main sidecar controller (discovery → update → seed)
```

### Key Commands

```bash
# Producer: extract and compress ledger
bash producer/snapshot.sh

# Producer: create torrent and publish to DHT
python -m producer.cli publish --private-key <HEX> --web-seed-url <URL>

# Producer: full pipeline (extract + compress + publish)
python -m producer.cli full --ledger-path /var/nano/data/data.ldb

# Mirror: start Docker container
docker compose up -d
```

### Testing

```bash
PYTHONPATH=$(pwd) pytest tests/ -v
```

Tests cover: BEP 46 signature buffer construction, sign/verify round-trips, BEP 46 test vectors (official), Nano address derivation, DHT value encoding.

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NANO_LEDGER_PATH` | Path to live `data.ldb` | `/var/nano/data/data.ldb` |
| `DHT_PRIVATE_KEY` | Ed25519 private key (hex) for Producer | Required for publish |
| `AUTHORITY_PUBKEY` | Ed25519 public key (hex) for Mirror | Required for mirror |
| `WEB_SEED_URL` | S3/HTTP mirror URL | `https://s3.us-east-2.amazonaws.com/repo.nano.org/snapshots/latest` |
| `DATA_DIR` | Mirror data volume path | `/data` |
| `POLL_INTERVAL` | DHT poll interval (seconds) | `600` |

### Dependencies

- **Runtime:** Python 3.12+, libtorrent 2.x (C++ built in Docker), pynacl, bencodepy, zstd
- **Build:** Docker (for Mirror image), cmake, boost (for libtorrent compilation)