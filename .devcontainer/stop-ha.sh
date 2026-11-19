#!/usr/bin/env bash
# Stop the Home Assistant that .devcontainer/start-ha.sh started, and wait until it is gone. Nothing to stop is not an error.
set -euo pipefail

TIMEOUT_SECONDS=30

pids="$(pgrep -f -- '[h]ass --config' || true)"
if [ -z "$pids" ]; then
    echo "Home Assistant is not running."
    exit 0
fi

# SIGTERM: Home Assistant stops its integrations and writes its state. start-ha.sh stops with it.
# shellcheck disable=SC2086
kill -TERM $pids
for _ in $(seq "$TIMEOUT_SECONDS"); do
    if ! pgrep -f -- '[h]ass --config' >/dev/null; then
        echo "Home Assistant is stopped."
        exit 0
    fi
    sleep 1
done
echo "Home Assistant did not stop in ${TIMEOUT_SECONDS} s." >&2
exit 1
