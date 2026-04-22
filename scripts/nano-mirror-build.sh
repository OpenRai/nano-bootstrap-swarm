#!/usr/bin/env bash
# nano-mirror-build — build the mirror Docker image with authority pubkey baked in
# Run on the server as the deploy user.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ME="${0##*/}"

usage() {
    cat <<EOF
Usage: $ME [--push]

Build the mirror image and optionally push to GHCR.
Reads AUTHORITY_PUBKEY from the repo root AUTHORITY_PUBKEY file.

Run on the server as the deploy user.

Options:
  --push   Build and push to GHCR (ghcr.io/openrai/nano-p2p-mirror:latest)
EOF
    exit 1
}

PUSH=false
while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --push) PUSH=true; shift ;;
        *) usage ;;
    esac
done

AUTHORITY_PUBKEY_FILE="$REPO_DIR/AUTHORITY_PUBKEY"

echo "=== Reading AUTHORITY_PUBKEY from $AUTHORITY_PUBKEY_FILE ==="
if [[ ! -f "$AUTHORITY_PUBKEY_FILE" ]]; then
    echo "ERROR: Missing $AUTHORITY_PUBKEY_FILE" >&2
    exit 1
fi

IFS= read -r PUBKEY < "$AUTHORITY_PUBKEY_FILE"
PUBKEY="${PUBKEY#"${PUBKEY%%[![:space:]]*}"}"
PUBKEY="${PUBKEY%"${PUBKEY##*[![:space:]]}"}"
if [[ "$PUBKEY" =~ ^[a-f0-9]{64}$ ]]; then
    echo "Found pubkey: ${PUBKEY:0:16}..."
else
    echo "ERROR: $AUTHORITY_PUBKEY_FILE must contain a 64-char lowercase hex public key" >&2
    exit 1
fi

echo "=== Building mirror image ==="
cd "$REPO_DIR"
IMG_TAG="ghcr.io/openrai/nano-p2p-mirror:latest"
docker build \
    --build-arg AUTHORITY_PUBKEY="$PUBKEY" \
    -t "$IMG_TAG" \
    -f mirror/Dockerfile .

echo "=== Image built: $IMG_TAG ==="
docker images "$IMG_TAG" --format "  {{.Repository}}:{{.Tag}}  {{.Size}}  {{.CreatedSince}}"

if $PUSH; then
    echo "=== Pushing to GHCR ==="
    docker push "$IMG_TAG"
    echo "=== Pushed: $IMG_TAG ==="
else
    echo ""
    echo "=== Not pushing (use --push to push to GHCR) ==="
fi
