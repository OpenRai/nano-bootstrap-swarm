# Validation & Testing Log

This document records results from manual validation tests of the Nano P2P Ledger Snapshot Service.

---

## Test Suite

### Test 1: The Delta Test
**Goal:** Confirm that an update to an existing ~80 GB ledger results in a download of < 5 GB.

| Metric | Target | Actual |
|--------|--------|--------|
| Delta download size | < 5 GB | _TBD_ |
| Force recheck time on SSD | < 20 min | _TBD_ |
| Total sync time (DHT discover → seeding) | < 60 min | _TBD_ |

**Procedure:**
1. Seed a full snapshot (v1) via the Producer.
2. Start a Mirror and allow it to download v1 completely.
3. Publish v2 via the Producer (small ledger change).
4. Observe the Mirror detect the update via DHT, force-recheck, and download only the delta.
5. Record total bytes downloaded vs. total file size.

**Results:** _Not yet performed_

---

### Test 2: The Zero-Peer Test
**Goal:** A fresh Mirror can bootstrap using only the S3 Web Seed when no P2P peers exist.

| Metric | Target | Actual |
|--------|--------|--------|
| Full bootstrap via web seed | Success | _TBD_ |
| Download completes without P2P peers | Yes | _TBD_ |
| Time to full download (web seed only) | < 4 hours | _TBD_ |

**Procedure:**
1. Start a fresh Mirror with empty `/data` directory.
2. Ensure no other P2P peers are available (fresh DHT, no other mirrors).
3. The Mirror should fall back to the web seed URL embedded in the torrent metadata.
4. Verify the full file downloads and the Mirror transitions to seeding.

**Results:** _Not yet performed_

---

### Test 3: The Identity Test
**Goal:** Verify the container logs correctly translate `AUTHORITY_PUBKEY` into the matching `nano_` address.

| Check | Expected | Actual |
|-------|----------|--------|
| Startup log shows Nano address | `nano_...` derived from pubkey | _TBD_ |
| Address matches official Nano Foundation address | Verified | _TBD_ |
| DHT signature verification works | Yes | _TBD_ |

**Procedure:**
1. Start the Mirror with a known `AUTHORITY_PUBKEY`.
2. Check the startup logs for the derived `nano_` address.
3. Verify it matches the known Nano address for that public key.
4. Confirm that DHT mutable item signature verification passes.

**Results:** _Not yet performed_

---

### Test 4: DHT Convergence Test
**Goal:** Mirror detects a Producer update within 30 minutes.

| Metric | Target | Actual |
|--------|--------|--------|
| DHT convergence time | < 30 min | _TBD_ |
| Sequence number correctly incremented | Yes | _TBD_ |
| Mirror_state.json updated | Yes | _TBD_ |

**Procedure:**
1. Producer publishes a new snapshot to DHT.
2. Record timestamp of publish.
3. Wait for Mirror to detect the update.
4. Record timestamp of detection in Mirror logs.
5. Calculate convergence time.

**Results:** _Not yet performed_

---

### Test 5: Persistence & Resume Test
**Goal:** Interrupted downloads resume without data loss.

| Check | Expected | Actual |
|-------|----------|--------|
| Download resumes after SIGTERM | Yes | _TBD_ |
| No data corruption after resume | Yes | _TBD_ |
| Pieces already downloaded are not re-downloaded | Yes | _TBD_ |

**Procedure:**
1. Start a Mirror download in progress.
2. Send SIGTERM to the container after 50% completion.
3. Restart the container.
4. Verify download resumes from where it left off.
5. Verify the final file passes integrity check (force recheck shows 100%).

**Results:** _Not yet performed_