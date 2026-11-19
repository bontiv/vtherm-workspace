#!/usr/bin/env bash
# Prepare the development environment: submodules, Python and Node dependencies of every project, and the Home Assistant configuration.
# Safe to run again. A failing dependency install is reported but does not stop the script: the rest of the environment stays usable.
set -euo pipefail

cd "$(dirname "$0")/.."

warn() { echo "WARNING: $*" >&2; }

# The workspace belongs to the user of the host, not to the user of the container: git refuses such folders without this.
git config --global safe.directory '*'

# The projects are submodules. A clone with --recurse-submodules has them already.
git submodule update --init --recursive

# The caches and the node_modules are Docker volumes: a new volume belongs to root.
sudo chown -R "$(id -u):$(id -g)" /var/cache/vtherm 2>/dev/null || true
for modules in vtherm_dashboard/node_modules vtherm_dashboard/frontend/node_modules versatile-thermostat-ui-card/node_modules; do
    sudo chown "$(id -u):$(id -g)" "$modules" 2>/dev/null || true
done

# --- Python ---------------------------------------------------------------------------------------------------------------------
python -m pip install --upgrade pip

# vtherm_api in editable mode: a change is picked up when Home Assistant restarts. It comes first, so that the requirements below,
# which ask for the published package (vtherm_api>=...), find it installed.
python -m pip install -e vtherm_api

install_requirements() {
    local project="$1" file
    for file in requirements_dev.txt requirements_test.txt requirements-dev.txt requirements.txt; do
        if [ -f "$project/$file" ]; then
            echo "Installing $project/$file"
            python -m pip install -r "$project/$file" || warn "$project/$file was not installed."
        fi
    done
}

# Versatile Thermostat first: its requirements_dev.txt pins the version of Home Assistant (and its tests need pytest-homeassistant).
install_requirements versatile_thermostat
install_requirements vtherm_dashboard
for project in vtherm_quirks vtherm_climate_replication vtherm_smartpi vtherm_hysteresis vtherm_pellet_stove vtherm_auto_fan_extended \
    vtherm_heating_failure_detection vtherm_inhibition; do
    install_requirements "$project"
done

# Dependencies of the Versatile Thermostat integration.
python -m pip install numpy scipy

# The browser of Home Assistant asks for the voice assistants and the cameras when it starts, and stays on "Loading data" without their
# packages. Install the ones that the installed Home Assistant requires, at the versions that it asks for.
python - <<'PYTHON' | xargs -r python -m pip install || warn "The packages of the voice assistants and cameras were not installed."
import json
import pathlib
import sys

root = pathlib.Path(sys.prefix) / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "site-packages" / "homeassistant" / "components"
seen, todo, requirements = set(), ["conversation", "ai_task", "assist_pipeline", "camera", "tts", "assist_satellite", "stt"], set()
while todo:
    name = todo.pop()
    manifest = root / name / "manifest.json"
    if name in seen or not manifest.exists():
        continue
    seen.add(name)
    data = json.loads(manifest.read_text(encoding="utf-8"))
    requirements.update(data.get("requirements", []))
    todo.extend(data.get("dependencies", []))
print("\n".join(sorted(requirements)))
PYTHON

# --- Node -----------------------------------------------------------------------------------------------------------------------
# The dashboard (npm workspaces: SDK and frontend) and the Versatile Thermostat card. auto-tpi-learning-card is not built here: its dist/
# is committed, and it commits its node_modules too, which npm would rewrite.
for project in vtherm_dashboard versatile-thermostat-ui-card; do
    if [ -f "$project/package-lock.json" ]; then
        echo "Installing the npm packages of $project"
        (cd "$project" && npm ci) || warn "npm ci failed in $project."
    fi
done

# --- Dashboard tests ------------------------------------------------------------------------------------------------------------
# The tests of the dashboard read Versatile Thermostat and vtherm_api from external/ (ignored by git in that project). Point them at the
# submodules of this workspace instead of cloning them again. HACS, which has no submodule here, is fetched by its own script.
mkdir -p vtherm_dashboard/external
for name in versatile_thermostat vtherm_api; do
    target="vtherm_dashboard/external/$name"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "$target exists and is not a link, left as it is."
    else
        ln -sfn "../../$name" "$target"
    fi
done
bash vtherm_dashboard/scripts/fetch-external.sh || warn "HACS was not fetched: the integration tests of the dashboard need it."

# --- Home Assistant -------------------------------------------------------------------------------------------------------------
mkdir -p config
if [ ! -f config/configuration.yaml ]; then
    cp .devcontainer/configuration.yaml config/configuration.yaml
fi
bash .devcontainer/link-components.sh

echo "Environment ready. Start Home Assistant with: bash .devcontainer/start-ha.sh"
