#!/usr/bin/env bash
# Start Home Assistant with the custom components of all the projects linked into config/custom_components.
#
# Usage: start-ha.sh [--dev-frontend]
#   --dev-frontend  Load the frontend of the dashboard from the development server (`npm run dev` in vtherm_dashboard) instead of the
#                   built files, by setting VTHERM_DASHBOARD_DEV_SERVER to http://localhost:5198. A value that is already set, for
#                   example the forwarded address of a Codespace, is kept.
#
# Stop it with Ctrl+C or with .devcontainer/stop-ha.sh: Home Assistant gets a SIGTERM and has the time to write its state.
# The log is written to config/home-assistant.log too.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

DEV_FRONTEND_URL="http://localhost:5198"

for argument in "$@"; do
    case "$argument" in
        --dev-frontend)
            export VTHERM_DASHBOARD_DEV_SERVER="${VTHERM_DASHBOARD_DEV_SERVER:-$DEV_FRONTEND_URL}"
            echo "The dashboard frontend is loaded from $VTHERM_DASHBOARD_DEV_SERVER: run 'npm run dev' in vtherm_dashboard, in another terminal."
            ;;
        *)
            echo "Unknown option: $argument" >&2
            echo "Usage: $0 [--dev-frontend]" >&2
            exit 2
            ;;
    esac
done

# The configuration of the development instance is created once, then it is yours (config/ is ignored by git).
mkdir -p config
if [ ! -f config/configuration.yaml ]; then
    cp .devcontainer/configuration.yaml config/configuration.yaml
fi

# A project may have been added or updated since the container was created.
bash .devcontainer/link-components.sh

child=0
forward_signal() {
    if [ "$child" -ne 0 ]; then
        kill -TERM "$child" 2>/dev/null || true
    fi
}
trap forward_signal INT TERM

# Home Assistant exits with the code 100 when it is asked to restart (the service homeassistant.restart), and leaves the restart to
# what started it: start it again then, and stop on any other code.
RESTART_EXIT_CODE=100
while true; do
    status=0
    hass --config "$ROOT/config" --debug &
    child=$!
    # `wait` returns early when the trap runs: wait again until Home Assistant is really gone, to get its exit code.
    wait "$child" || status=$?
    while kill -0 "$child" 2>/dev/null; do
        wait "$child" || status=$?
    done
    child=0
    if [ "$status" -ne "$RESTART_EXIT_CODE" ]; then
        exit "$status"
    fi
    echo "Home Assistant asked for a restart: starting it again."
done
