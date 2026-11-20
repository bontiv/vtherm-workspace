#!/usr/bin/env bash
# Prepare the development environment: submodules, Python and Node dependencies of every project, and the Home Assistant configuration.
# Safe to run again. A failing dependency install is reported but does not stop the script: the rest of the environment stays usable.
set -euo pipefail

cd "$(dirname "$0")/.."

warn() { echo "WARNING: $*" >&2; }

# The workspace belongs to the user of the host, not to the user of the container: git refuses such folders without this.
git config --global safe.directory '*'

# A clone made on Windows has CRLF line endings (core.autocrlf=true there), while the index of every project has LF. Without this, git in
# the container sees every file as modified. "input" leaves the files as they are and keeps LF in the commits.
git config --global core.autocrlf input

# The projects are submodules. A clone with --recurse-submodules has them already.
git submodule update --init --recursive

# The caches and the node_modules are Docker volumes: a new volume belongs to root.
sudo chown -R "$(id -u):$(id -g)" /var/cache/vtherm 2>/dev/null || true
for modules in vtherm_dashboard/node_modules vtherm_dashboard/frontend/node_modules versatile-thermostat-ui-card/node_modules; do
    sudo chown "$(id -u):$(id -g)" "$modules" 2>/dev/null || true
done

# VS Code gives the settings of a folder priority over the ones of the workspace. A project that names an interpreter of its own in its
# .vscode/settings.json (for example /workspaces/vtherm_pellet_stove/.venv/bin/python, the path of its own container) makes VS Code report
# that the interpreter cannot be resolved. The path of such a setting becomes a link to the interpreter of this container. The projects
# are not changed.
for settings in */.vscode/settings.json; do
    [ -f "$settings" ] || continue
    interpreter="$(grep -oE '"python\.(defaultInterpreterPath|pythonPath)"[[:space:]]*:[[:space:]]*"[^"]+"' "$settings" | head -n 1 | sed -E 's/.*:[[:space:]]*"([^"]+)"/\1/' || true)"
    case "$interpreter" in /*) ;; *) continue ;; esac
    if [ ! -e "$interpreter" ]; then
        sudo mkdir -p "$(dirname "$interpreter")" && sudo ln -sf "$(command -v python)" "$interpreter" \
            || warn "The interpreter $interpreter of $settings could not be linked."
    fi
done

# --- Python ---------------------------------------------------------------------------------------------------------------------
python -m pip install --upgrade pip

# vtherm_api in editable mode: a change is picked up when Home Assistant restarts. It comes first, so that the requirements below,
# which ask for the published package (vtherm_api>=...), find it installed.
python -m pip install -e vtherm_api

# The version of Home Assistant is the one that Versatile Thermostat pins in its requirements_dev.txt. Several projects pin another one
# (homeassistant==2026.3.1, ...): installed after it, they would replace it. So the "homeassistant" lines of the other projects are left
# out, and every install runs under a constraint on the version of Versatile Thermostat.
HA_PIN="$(grep -E '^[[:space:]]*homeassistant==' versatile_thermostat/requirements_dev.txt | head -n 1 | tr -d '[:space:]' || true)"
CONSTRAINTS=""
if [ -n "$HA_PIN" ]; then
    CONSTRAINTS="$(mktemp)"
    echo "$HA_PIN" > "$CONSTRAINTS"
    echo "Home Assistant is kept at $HA_PIN, as versatile_thermostat/requirements_dev.txt pins it."
else
    warn "versatile_thermostat/requirements_dev.txt does not pin homeassistant: the version is left to pip."
fi

install_requirements() {
    local project="$1" file source filtered requested
    for file in requirements_dev.txt requirements_test.txt requirements-dev.txt requirements.txt; do
        source="$project/$file"
        [ -f "$source" ] || continue
        # The filtered copy is next to the original, and pip runs in the project: the relative lines of a requirements file
        # ("-r requirements_dev.txt", "-e .") still find their target. The copy is removed after the install.
        filtered="$(mktemp -p "$project" .requirements.XXXXXX)"
        if [ "$project" = versatile_thermostat ]; then
            cp "$source" "$filtered"
        else
            # "homeassistant", "homeassistant==x", "homeassistant>=x": not "home-assistant-frontend" or "homeassistant-foo".
            # pytest-homeassistant-custom-component pins one exact Home Assistant: under the constraint, pip would fall back to a
            # very old release. It is installed once, after the projects (see below).
            # The "-r other.txt" lines are dropped: every requirements file of the project is installed in its own turn, and an included
            # file would bring back the homeassistant line that was just removed.
            grep -Ev '^[[:space:]]*(homeassistant([[:space:]]*([=<>!~;#]|$))|pytest-homeassistant-custom-component|-r[[:space:]]|--requirement)' "$source" > "$filtered" || true
            if grep -qE '^[[:space:]]*pytest-homeassistant-custom-component' "$source"; then
                NEEDS_PHCC=1
            fi
            requested="$(grep -E '^[[:space:]]*homeassistant[[:space:]]*[=<>!~]' "$source" | tr -d '[:space:]' | head -n 1 || true)"
            if [ -n "$requested" ] && [ -n "$HA_PIN" ] && [ "$requested" != "$HA_PIN" ]; then
                warn "$source asks for $requested: $HA_PIN is kept."
            fi
        fi
        echo "Installing $source"
        (cd "$project" && python -m pip install ${CONSTRAINTS:+-c "$CONSTRAINTS"} -r "$(basename "$filtered")") || warn "$source was not installed."
        rm -f "$filtered"
    done
}

NEEDS_PHCC=0

# Versatile Thermostat first: its requirements_dev.txt pins the version of Home Assistant (and its tests need pytest-homeassistant).
install_requirements versatile_thermostat
install_requirements vtherm_dashboard
for project in vtherm_quirks vtherm_climate_replication vtherm_smartpi vtherm_hysteresis vtherm_pellet_stove vtherm_auto_fan_extended \
    vtherm_heating_failure_detection vtherm_inhibition; do
    install_requirements "$project"
done

# Dependencies of the Versatile Thermostat integration.
python -m pip install ${CONSTRAINTS:+-c "$CONSTRAINTS"} numpy scipy

# pytest-homeassistant-custom-component (the tests of several projects use it) pins the Home Assistant that it was extracted from, and
# the last release is often older than Home Assistant. It is installed without its dependencies, so that it does not replace the pinned
# version; its other dependencies are then installed under the constraint. Its fixtures may differ a little from the ones of that version.
if [ "$NEEDS_PHCC" = 1 ]; then
    python -m pip install --no-deps --upgrade pytest-homeassistant-custom-component \
        || warn "pytest-homeassistant-custom-component was not installed: the tests that import it will fail."
    python - <<'PYTHON' | xargs -r python -m pip install ${CONSTRAINTS:+-c "$CONSTRAINTS"} \
        || warn "Some dependencies of pytest-homeassistant-custom-component were not installed: run 'pip check' to see which."
from importlib.metadata import PackageNotFoundError, requires

try:
    from packaging.requirements import Requirement
except ImportError:  # packaging comes with pip's vendored copy otherwise
    from pip._vendor.packaging.requirements import Requirement

try:
    texts = requires("pytest-homeassistant-custom-component") or []
except PackageNotFoundError:
    texts = []
for text in texts:
    requirement = Requirement(text)
    if requirement.name.lower() == "homeassistant":
        continue
    if requirement.marker is not None and not requirement.marker.evaluate({"extra": ""}):
        continue
    print(f"{requirement.name}{requirement.specifier}")
PYTHON
    warn "pytest-homeassistant-custom-component was installed without the Home Assistant that it pins: its fixtures come from another version."
fi

# The browser of Home Assistant asks for the voice assistants and the cameras when it starts, and stays on "Loading data" without their
# packages. Install the ones that the installed Home Assistant requires, at the versions that it asks for.
python - <<'PYTHON' | xargs -r python -m pip install ${CONSTRAINTS:+-c "$CONSTRAINTS"} || warn "The packages of the voice assistants and cameras were not installed."
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

# No project may have replaced the version of Home Assistant.
installed="$(python -m pip show homeassistant 2>/dev/null | sed -n 's/^Version: //p')"
if [ -n "$HA_PIN" ] && [ "homeassistant==$installed" != "$HA_PIN" ]; then
    warn "Home Assistant $installed is installed, but versatile_thermostat/requirements_dev.txt pins $HA_PIN."
fi
[ -z "$CONSTRAINTS" ] || rm -f "$CONSTRAINTS"

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
