# Getting Started with the Nano P2P Mirror

This tutorial walks you through your first successful run of the mirror service using Docker.

---

## Prerequisites

- Docker installed and running
- ~80 GB of free disk space (for the full Nano ledger)
- Port 6881 available (TCP and UDP) — or reconfigure via `ports` in `docker-compose.yml`
- An `AUTHORITY_PUBKEY` — the Ed25519 public key of the authority whose snapshots you want to mirror

---

## Step 1: Get the Authority Public Key

The mirror will only trust snapshots signed by the authority whose public key you configure. If you operate your own producer, use the public key that corresponds to your `DHT_PRIVATE_KEY`. If you want to mirror an existing authority, obtain their public key through a trusted channel.

The public key is 32 bytes (64 hex characters).

---

## Step 2: Build the Image

```bash
git clone https://github.com/OpenRai/nano-bootstrap-swarm.git
cd nano-bootstrap-swarm
docker build -f mirror/Dockerfile -t nano-bootstrap-mirror .
```

Or pull the pre-built image (once published):

```bash
docker pull ghcr.io/openrai/nano-p2p-mirror:latest
```

---

## Step 3: Run the Mirror

### Option A: Docker Compose (recommended for swarm mode)

```bash
export AUTHORITY_PUBKEY=<your_64_char_hex_pubkey>
docker compose up -d
```

### Option B: Docker Run

```bash
docker run -d \
  --name nano-mirror \
  -e AUTHORITY_PUBKEY=<your_64_char_hex_pubkey> \
  -p 6881:6881/tcp -p 6881:6881/udp \
  -v nano-data:/data \
  ghcr.io/openrai/nano-p2p-mirror:latest
```

---

## Step 4: Verify It's Working

Check the logs:

```bash
docker compose logs -f
# or
docker logs -f nano-mirror
```

Look for these log lines:

```
Nano P2P Mirror Service Starting
Authority Nano address: nano_...
Authority public key: <first 8 bytes>...
DHT bootstrap nodes added
Waiting 30s for DHT to bootstrap...
```

After ~30 seconds the first discovery cycle runs:

```
Querying DHT for mutable item (target: <hash>..., salt: 'daily')
Discovered DHT item: seq=..., info_hash=<hash>...
New snapshot detected!
```

Check the healthcheck:

```bash
docker compose ps
# or
docker inspect --format='{{.State.Health.Status}}' nano-mirror
```

A healthy container shows `healthy`.

---

## What Happens Next

The mirror follows this sequence:

1. **DHT Bootstrap** (~30s) — connects to public DHT bootstrap nodes
2. **Discovery** — queries the DHT for a mutable item under `AUTHORITY_PUBKEY` with salt `daily`
3. **Download** — if a new snapshot is found, downloads it via BitTorrent (with S3 web-seed fallback)
4. **Force Recheck** — verifies existing local data against the new torrent
5. **Seeding** — once complete, seeds the snapshot back to the P2P network
6. **Repeat** — every `POLL_INTERVAL` seconds (default: 600 = 10 minutes), it re-checks for updates

The first run may take hours for a full ledger (~80 GB). Subsequent runs should be much faster if only delta pieces have changed.

---

## Data on Disk

The `nano-data` volume (or your bind mount at `/data`) contains:

| File | Description |
|---|---|
| `nano-daily.ldb.zst` | Compressed ledger snapshot (or whatever the torrent is named) |
| `mirror_state.json` | Last known sequence number and info-hash. **Persists across restarts.** |

---

## Next Steps

- **Swarm mode** (long-running mirror): see [docs/mirror-swarm-mode.md](mirror-swarm-mode.md)
- **Leech mode** (one-shot download): see [docs/mirror-leech-mode.md](mirror-leech-mode.md)
- **All configuration options**: see [docs/configuration.md](configuration.md)
