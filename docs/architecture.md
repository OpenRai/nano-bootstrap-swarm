# Architecture

How the Nano P2P Ledger Snapshot Service works under the hood.

---

## Overview

The system has two roles:

- **Producer** — runs on an authority node with a live Nano ledger. Periodically snapshots the LMDB database, compresses it, creates a BitTorrent v2 torrent, and publishes the info-hash + metadata to the Mainline DHT under an Ed25519 key.
- **Mirror** — runs on any machine. Polls the DHT for items under a configured authority public key. When it finds a new info-hash, it downloads the torrent (with S3 web-seed fallback), verifies the existing local data, and seeds it back to the P2P network.

The key insight is **delta efficiency**: because the ledger database changes slowly and predictably, and because `zstd --rsyncable` aligns compression block boundaries with piece boundaries, BitTorrent can download only the changed pieces on each update rather than the full ~80 GB ledger.

---

## BEP 46: Mutable Torrents in DHT

[BitTorrent BEP 46](http://www.bittorrent.org/beps/bep_0046.html) defines how to store mutable items in the Mainline DHT.

A mutable item is stored at a key derived from the authority's Ed25519 public key:

```
target_id = SHA1(public_key_bytes [+ salt])
```

The DHT value is a bencoded dict containing:

```python
{
    "info_hash": <32-byte torrent info-hash>,
    "v": 2,                      # protocol version
    "piece_size": 33554432,      # 32 MiB
}
```

The value is signed with the Ed25519 private key using the BEP 46 signature scheme:

```
signature = Ed25519_sign(
    key = private_key,
    message = BEP46_signature_buffer(seq, value, salt)
)
```

Mirrors verify the signature before accepting the item. This prevents a passive attacker from injecting fake info-hashes into the DHT.

---

## The Update Flow

```
┌─────────────┐     mdb_copy + zstd      ┌──────────────────────┐
│  Nano node  │ ───────────────────────► │  Snapshot file        │
│  (LMDB)     │                            │  nano-daily.ldb.zst  │
└─────────────┘                            └──────────┬───────────┘
                                                      │
                                             BitTorrent v2
                                             torrent create
                                                      │
                                                      ▼
                                             ┌──────────────────────┐
                                             │  .torrent file       │
                                             │  (info_hash, pieces) │
                                             └──────────┬───────────┘
                                                      │
                                           publish_to_dht()
                                           (Ed25519 sign + DHT put)
                                                      │
                                                      ▼
                                             ┌──────────────────────┐
                                             │  Mainline DHT        │
                                             │  mutable item at     │
                                             │  SHA1(pubkey+salt)   │
                                             └──────────────────────┘
                                                      ▲
                                                      │ dht_get_mutable_item()
                                              ┌───────┴───────────┐
                                              │  Mirror(s)       │
                                              └───────────────────┘
```

---

## Mirror Discovery and Download

When a mirror starts:

1. **DHT bootstrap** — connects to public bootstrap nodes, builds its routing table
2. **Discovery cycle** — queries DHT for mutable item at `SHA1(AUTHORITY_PUBKEY + DHT_SALT)`
3. **Signature verification** — verifies the returned item's Ed25519 signature against `AUTHORITY_PUBKEY`
4. **Sequence comparison** — if `seq <= last_seq`, skip; otherwise it's a new snapshot
5. **Torrent addition** — adds via magnet URI (`magnet:?xt=urn:btmh:<info_hash>&ws=<web_seed_url>`)
6. **Force recheck** — tells libtorrent to verify existing pieces against the new torrent's merkle tree
7. **Delta download** — only missing or changed pieces are downloaded from peers + web seed
8. **Seeding** — once 100% complete, the mirror seeds to the P2P network

---

## Why zstd --rsyncable

Standard `zstd` compression produces a single compressed stream. If you compress the same file and only 1% of bytes change, the compressed output is almost entirely different — useless for delta transfer.

`--rsyncable` periodically resets the compression state so that small local changes produce localized changes in the compressed output. Critically, when combined with piece-aligned block boundaries (32 MiB pieces), this means:

- A small change in the LMDB database → only the affected piece(s) change
- BitTorrent downloads only those changed pieces — not the whole 80 GB

The `--rsyncable` flag adds a small overhead (~1-2% compressed size) but enables order-of-magnitude bandwidth savings on incremental updates.

---

## Web Seed Fallback

The magnet URI includes the S3 URL as a web seed:

```
magnet:?xt=urn:btmh:<info_hash>&ws=https://s3.us-east-2.amazonaws.com/repo.nano.org/snapshots/latest
```

If no P2P peers are available (cold swarm), the mirror downloads directly from S3. This ensures bootstrap works even with zero peers.

---

## Security Model

1. **DHT integrity** — mutable items are Ed25519-signed. Mirrors reject unsigned or incorrectly-signed items.
2. **Authority-only publishing** — only the holder of the private key can publish new info-hashes. The public key is the identity.
3. **No MITM on DHT** — an active attacker who cannot forge signatures cannot redirect mirrors to fake torrents.
4. **Web seed integrity** — the BitTorrent piece hash verification ensures the downloaded file matches the info-hash published to DHT, even when fetched from S3.

---

## Salt Namespaces

The DHT salt allows multiple snapshot streams under the same Ed25519 key:

| Salt | Typical use |
|---|---|
| `daily` | Daily snapshots |
| `weekly` | Weekly snapshots |

Mirrors subscribe to one salt at a time via `DHT_SALT`. Changing the salt produces an entirely separate DHT key, so the two streams don't interfere.

---

## State Files

| File | Who writes it | Purpose |
|---|---|---|
| `mirror_state.json` | Mirror (swarm) | Track last known `seq` and `info_hash`. Survives restarts. |
| `publisher_state.json` | Producer | Track last published `seq` and `info_hash`. Ensures monotonic sequence. |
