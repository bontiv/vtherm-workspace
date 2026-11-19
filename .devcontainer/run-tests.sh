#!/usr/bin/env bash
# Run the Python tests of one project: run-tests.sh <project> [pytest arguments]
# The project is the name of a submodule folder, for example versatile_thermostat or vtherm_dashboard.
set -euo pipefail

cd "$(dirname "$0")/.."

project="${1:-}"
if [ -z "$project" ]; then
    echo "Usage: $0 <project> [pytest arguments]" >&2
    exit 2
fi
shift

# The project must be one of the submodules: no path, no "..".
if ! git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}' | grep -qxF -- "$project"; then
    echo "Unknown project: $project (see .gitmodules)" >&2
    exit 2
fi
if [ ! -d "$project/tests" ]; then
    echo "$project has no tests/ folder." >&2
    exit 2
fi

cd "$project"
exec python -m pytest "$@"
