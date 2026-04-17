#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-/opt/nano-snapshots}"
LEDGER_OUTPUT="${OUTPUT_DIR}/data.ldb"
WEB_SEED_URL="${WEB_SEED_URL:-https://s3.us-east-2.amazonaws.com/repo.nano.org/snapshots/latest}"
AGENT="nano-bootstrap-swarm/1.0"

LOG_FILE="${LOG_FILE:-${OUTPUT_DIR}/nano-snapshot.log}"

log() {
    echo "[$(date -Iseconds)] $*" | tee -a "$LOG_FILE"
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

log "=== Starting daily snapshot pipeline ==="

# --- Step 1: Fetch latest snapshot from S3 ---
log "Fetching latest snapshot from S3"

LATEST_URL=$(curl -sSL -A "$AGENT" "$WEB_SEED_URL" | tr -d '"')
if [ -z "$LATEST_URL" ]; then
    log "ERROR: Could not determine latest snapshot URL from $WEB_SEED_URL"
    exit 1
fi

FILENAME=$(basename "$LATEST_URL")
log "Downloading $LATEST_URL"

curl -sSL -A "$AGENT" -o "${TMPDIR}/${FILENAME}" "$LATEST_URL"

if [ ! -f "${TMPDIR}/${FILENAME}" ]; then
    log "ERROR: Download failed — file not found"
    exit 1
fi

ORIG_SIZE=$(stat -c%s "${TMPDIR}/${FILENAME}")
log "Downloaded ${FILENAME} (${ORIG_SIZE} bytes)"

# --- Step 2: Extract ---
log "Extracting ${FILENAME}"
7z x -y -o"${TMPDIR}" "${TMPDIR}/${FILENAME}" > /dev/null

if [ ! -f "${TMPDIR}/data.ldb" ]; then
    log "ERROR: Extraction failed — data.ldb not found"
    exit 1
fi

EXTRACTED_SIZE=$(stat -c%s "${TMPDIR}/data.ldb")
log "Extracted data.ldb (${EXTRACTED_SIZE} bytes)"

# --- Step 3: Compress with zstd rsyncable ---
COMPRESSED_OUTPUT="${OUTPUT_DIR}/nano-daily.ldb.zst"
log "Compressing with zstd -3 --rsyncable"
zstd -3 --rsyncable -f "${TMPDIR}/data.ldb" -o "$COMPRESSED_OUTPUT"

COMP_SIZE=$(stat -c%s "$COMPRESSED_OUTPUT")
SHA256=$(sha256sum "$COMPRESSED_OUTPUT" | cut -d' ' -f1)
log "Compressed to ${COMPRESSED_OUTPUT} (${COMP_SIZE} bytes, sha256=${SHA256})"

# --- Step 4: Create torrent ---
TORRENT_OUTPUT="${OUTPUT_DIR}/nano-daily.ldb.torrent"
log "Creating torrent"

cd /opt/nano-bootstrap-swarm
source .venv/bin/activate
source /home/openrai/.env

python -m producer.cli publish \
    --ledger-path "$COMPRESSED_OUTPUT" \
    --private-key "$DHT_PRIVATE_KEY" \
    --output-dir "$OUTPUT_DIR" \
    --web-seed-url "$WEB_SEED_URL"

log "=== Daily snapshot pipeline complete ==="
