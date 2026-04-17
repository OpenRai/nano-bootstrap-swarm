#!/usr/bin/env bash
set -euo pipefail

NANO_LEDGER_PATH="${NANO_LEDGER_PATH:-/var/nano/data/data.ldb}"
OUTPUT_DIR="${OUTPUT_DIR:-.}"
OUTPUT_FILE="${OUTPUT_DIR}/nano-daily.ldb.zst"

MDB_COPY="$(command -v mdb_copy || true)"
if [ -z "$MDB_COPY" ]; then
    echo "ERROR: mdb_copy not found in PATH" >&2
    exit 1
fi

ZSTD="$(command -v zstd || true)"
if [ -z "$ZSTD" ]; then
    echo "ERROR: zstd not found in PATH" >&2
    exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "[$(date -Iseconds)] Starting snapshot pipeline"

echo "[$(date -Iseconds)] Running mdb_copy on ${NANO_LEDGER_PATH}"
"$MDB_COPY" "$NANO_LEDGER_PATH" "$TMPDIR/data.ldb"

if [ ! -f "$TMPDIR/data.ldb" ]; then
    echo "ERROR: mdb_copy failed — output file not found" >&2
    exit 1
fi

ORIG_SIZE=$(stat -f%z "$TMPDIR/data.ldb" 2>/dev/null || stat -c%s "$TMPDIR/data.ldb" 2>/dev/null || echo "unknown")
echo "[$(date -Iseconds)] Copy size: ${ORIG_SIZE} bytes"

echo "[$(date -Iseconds)] Compressing with zstd -3 --rsyncable"
"$ZSTD" -3 --rsyncable -f "$TMPDIR/data.ldb" -o "$OUTPUT_FILE"

COMP_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "unknown")
echo "[$(date -Iseconds)] Compressed size: ${COMP_SIZE} bytes"

SHA256=$(shasum -a 256 "$OUTPUT_FILE" | cut -d' ' -f1)
echo "[$(date -Iseconds)] SHA-256: ${SHA256}"

echo "[$(date -Iseconds)] Snapshot complete: ${OUTPUT_FILE}"