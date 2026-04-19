#!/usr/bin/env bash
# nano-snapshot status — check timer state and recent journal entries
# Run on the server as the deploy user.
set -euo pipefail

ME="${0##*/}"

usage() {
    cat <<EOF
Usage: $ME [log-lines]

Run on the server as the deploy user.

Examples:
  $ME          # timer status + last 20 log lines
  $ME 50       # timer status + last 50 log lines
EOF
    exit 1
}

LOG_LINES=20
if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    LOG_LINES="$1"
fi

systemctl --user list-timers nano-snapshot --no-pager
echo
journalctl --user -u nano-snapshot -n "$LOG_LINES" --no-pager
