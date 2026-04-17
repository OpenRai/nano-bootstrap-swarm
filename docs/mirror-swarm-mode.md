# Swarm Mode: Long-Running Seeding Mirror

Swarm mode is the default operational mode. The mirror runs as a daemon, polling the DHT every `POLL_INTERVAL` seconds, downloading new snapshots as they appear, and seeding them back to the P2P network.

---

## Starting in Swarm Mode

### Docker Compose

```bash
export AUTHORITY_PUBKEY=<your_pubkey_hex>
docker compose up -d
```

### Docker Run

```bash
docker run -d \
  --name nano-mirror \
  -e AUTHORITY_PUBKEY=<your_pubkey_hex> \
  -p 6881:6881/tcp -p 6881:6881/udp \
  -v $(pwd)/data:/data \
  ghcr.io/openrai/nano-p2p-mirror:latest
```

---

## Monitoring

### Docker Logs

```bash
docker compose logs -f
# or
docker logs -f nano-mirror
```

Key log messages to expect:

| Log | Meaning |
|---|---|
| `Authority Nano address: nano_...` | Pubkey correctly decoded to Nano address |
| `Querying DHT for mutable item...` | Discovery cycle running |
| `Discovered DHT item: seq=N` | Found a snapshot |
| `New snapshot detected!` | Newer than stored seq, downloading |
| `Force recheck on existing data...` | Verifying existing pieces |
| `Download: 45.2% \| State: downloading` | Active download progress |
| `Snapshot seeding complete` | Download done, now seeding |
| `Mirror service stopped` | Clean shutdown |

### Healthcheck

```bash
docker compose ps
docker inspect --format='{{.State.Health.Status}}' nano-mirror
```

The container healthcheck runs: `python3 -c "import libtorrent; libtorrent.session({'enable_dht': False})"`

### mirror_state.json

Persisted state survives restarts:

```bash
docker exec nano-mirror cat /data/mirror_state.json
```

```json
{
  "last_seq": 42,
  "last_info_hash": "abcd1234...",
  "current_torrent_name": "nano-daily.ldb.zst"
}
```

---

## Tuning

### POLL_INTERVAL

How often to check DHT for new snapshots (in seconds). Default: `600` (10 minutes).

```yaml
environment:
  POLL_INTERVAL: "3600"  # Check once per hour
```

### DHT_SALT

The DHT namespace. Default: `daily`. Using a different salt lets you operate a separate snapshot stream (e.g., `weekly`) alongside the default.

```yaml
environment:
  DHT_SALT: "weekly"
```

### LOG_LEVEL

```yaml
environment:
  LOG_LEVEL: DEBUG  # Verbose logging
```

---

## Updating the Container

```bash
# Rebuild
docker build -f mirror/Dockerfile -t nano-bootstrap-mirror .

# Pull latest published image
docker pull ghcr.io/openrai/nano-p2p-mirror:latest

# Restart with new image
docker compose down
docker compose up -d
```

State is preserved in the `nano-data` volume. No data is lost on restart.

---

## Troubleshooting

### "Authority Nano address" doesn't match expected

Your `AUTHORITY_PUBKEY` may be wrong or byteswapped. The hex is interpreted as raw bytes of the Ed25519 public key. Double-check the source of the key.

### "Signature verification FAILED"

The DHT returned a mutable item at your authority key, but the Ed25519 signature didn't verify. This means either:
- The item was placed by a different private key
- The data was tampered with in transit

The mirror rejects such items and retries on the next poll cycle.

### DHT discovery takes a long time

DHT bootstrap can take 5–15 minutes on a cold start, especially behind NAT. The 30-second bootstrap wait is intentionally conservative. If peers never appear, the mirror will still download via the web seed (S3 fallback).

### Download appears stuck at 0%

Check `num_peers: 0`. If the torrent has no peers and no web seed is reachable, the download cannot proceed. This can happen if:
- The web seed URL is unreachable from your network
- The torrent info-hash is not yet announced to any tracker (if trackers are used)

Use `--log-level DEBUG` and look for `alert` messages to understand what's happening.

### Volume Permissions

If you see errors about `/data` being unwritable:

```bash
sudo chown -R 1000:1000 ./data
```

The container runs as UID 1000 by default.

---

## Stopping

```bash
docker compose down
# or
docker stop nano-mirror
```

The mirror handles `SIGTERM` gracefully and saves state before exiting.
