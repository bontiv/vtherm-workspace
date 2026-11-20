# Versatile Thermostat workspace

A VS Code dev container and a multi-root workspace to work on [Versatile Thermostat](https://github.com/jmcollin78/versatile_thermostat)
(VTherm) and the projects around it, in one Home Assistant development instance. Each project is a git submodule, pinned to one commit.

Nothing in this repository depends on your computer: no absolute path, no user name. Everything uses `${localWorkspaceFolder}`,
`${containerWorkspaceFolder}`, relative paths and Docker volumes.

## Projects

| Folder | Repository | Role |
| --- | --- | --- |
| `versatile_thermostat` | [jmcollin78/versatile_thermostat](https://github.com/jmcollin78/versatile_thermostat) | The integration |
| `vtherm_api` | [jmcollin78/vtherm_api](https://github.com/jmcollin78/vtherm_api) | The API shared by the integration and its plugins (Python package, installed in editable mode) |
| `vtherm_dashboard` | [bontiv/vtherm_dashboard](https://github.com/bontiv/vtherm_dashboard) | The dashboard (default branch `master`) |
| `vtherm_quirks` | [bontiv/vtherm_quirks](https://github.com/bontiv/vtherm_quirks) | Quirks (before-write hooks) for VTherm |
| `vtherm_climate_replication` | [jmcollin78/vtherm_climate_replication](https://github.com/jmcollin78/vtherm_climate_replication) | Plugin |
| `vtherm_smartpi` | [KipK/vtherm_smartpi](https://github.com/KipK/vtherm_smartpi) | Plugin (default branch `master`) |
| `vtherm_hysteresis` | [KipK/vtherm_hysteresis](https://github.com/KipK/vtherm_hysteresis) | Plugin |
| `vtherm_pellet_stove` | [jmcollin78/vtherm_pellet_stove](https://github.com/jmcollin78/vtherm_pellet_stove) | Plugin |
| `vtherm_auto_fan_extended` | [jmcollin78/vtherm_auto_fan_extended](https://github.com/jmcollin78/vtherm_auto_fan_extended) | Plugin |
| `vtherm_heating_failure_detection` | [jmcollin78/vtherm_heating_failure_detection](https://github.com/jmcollin78/vtherm_heating_failure_detection) | Plugin |
| `vtherm_inhibition` | [alexlenk/vtherm_inhibition](https://github.com/alexlenk/vtherm_inhibition) | Plugin |
| `heating-simulator` | [caiusseverus/heating-simulator](https://github.com/caiusseverus/heating-simulator) | Heating simulator (an integration at the root of its repository) |
| `versatile-thermostat-ui-card` | [jmcollin78/versatile-thermostat-ui-card](https://github.com/jmcollin78/versatile-thermostat-ui-card) | Lovelace card (default branch `master`) |
| `auto-tpi-learning-card` | [KipK/auto-tpi-learning-card](https://github.com/KipK/auto-tpi-learning-card) | Lovelace card |

The list comes from the `mounts` of the
[dev container of Versatile Thermostat](https://github.com/jmcollin78/versatile_thermostat/blob/main/.devcontainer/devcontainer.json),
plus `vtherm_dashboard` and `vtherm_quirks`. The repository of each plugin was found by name, and every URL answers to `git ls-remote`.
The dev container of Versatile Thermostat gives paths on the computer of its author, not URLs: check that these are the repositories you want.

## Requirements

- Docker (Docker Desktop, or Docker Engine) and VS Code with the extension **Dev Containers**.
- git 2.x. On Windows, run `git config --global core.autocrlf input` **before** cloning: `.gitattributes` forces LF in this repository only, not in the submodules (see [Windows and WSL](#windows-and-wsl)).
- About 10 GB of disk space and 8 GB of memory for Docker: Home Assistant, Node and the dependencies of all the projects.

## Get started

```bash
git clone --recurse-submodules <url of this repository> vtherm-workspace
code vtherm-workspace
```

> **The submodules must be fetched before you start the dev container.** If the project folders are empty (a clone without
> `--recurse-submodules`), `post-create.sh` fails, for example on `pip install -e vtherm_api` ("neither `setup.py` nor `pyproject.toml` found").
> After a plain `git clone`, run this on the host, before **Reopen in Container**:
>
> ```bash
> git submodule update --init --recursive
> ```
>
> If the container already failed, run the command, then **Dev Containers: Rebuild Container** (or `bash .devcontainer/post-create.sh`).
> `git submodule status` must show no `-` in front of a project.

1. In VS Code: **Dev Containers: Reopen in Container**. The first build takes several minutes: `postCreateCommand` runs
   `git submodule update --init --recursive` again (a no-op when the submodules are already there), installs the Python and Node
   dependencies, and prepares `config/`. Read its output in the terminal if something fails: a failing install is a warning, not a stop.
2. **File > Open Workspace from File...** and choose `vtherm.code-workspace`. Each project becomes a folder, with the common settings,
   the recommended extensions, the tasks and the launch configurations.
3. Start Home Assistant: task **Home Assistant: start**, or `bash .devcontainer/start-ha.sh`. Open <http://localhost:8123> and create
   the user (onboarding). Add the integrations from **Settings > Devices & services**.

### Home Assistant

| What | How |
| --- | --- |
| Start | `bash .devcontainer/start-ha.sh` |
| Start, dashboard frontend from the development server | `npm run dev` in `vtherm_dashboard`, then `bash .devcontainer/start-ha.sh --dev-frontend` |
| Stop (clean: SIGTERM, waits for the end) | `bash .devcontainer/stop-ha.sh`, or Ctrl+C in the terminal that runs it |
| Restart after a change of Python code | Task **Home Assistant: restart**. A restart asked from Home Assistant itself (exit code 100) is done by `start-ha.sh` |
| Reload the links after adding or updating a project | `bash .devcontainer/link-components.sh` (`start-ha.sh` does it at each start) |
| Log | Home Assistant's output, and `config/home-assistant.log` (task **Home Assistant: follow the log**) |
| Debug | Launch configuration **Home Assistant: launch with the debugger**, or **attach** to port 5678 (the `debugpy` integration) |
| Tests of one project | Task **Tests: pytest of a project**, or `bash .devcontainer/run-tests.sh <project> [pytest arguments]` |

The dashboard needs its frontend: `npm run build` in `vtherm_dashboard` (built files) or the development server above.
See `vtherm_dashboard/docs/contributing/development-environment.md`.

The configuration of Home Assistant is `config/configuration.yaml`, copied from `.devcontainer/configuration.yaml` once. After that it is
yours (`config/` is ignored by git). It has fake sensors, heaters and underlying thermostats to create VTherm thermostats without hardware.

## How it works

### Design decisions

- **Submodules, one commit each.** The workspace repository records the exact commit of each project, so two people get the same
  environment. Nothing here is a copy of a project. The submodules were added with `git submodule add --depth 1` (a shallow clone on this
  computer only; `.gitmodules` does not ask for shallow clones, so you get the full history). `.gitmodules` has a `branch` for each project, used
  only by `git submodule update --remote`. A submodule is in the state "detached HEAD": check a branch out in it before you commit.
- **One folder in the container.** `workspaceMount` and `workspaceFolder` mount this repository (the folder you opened) at
  `/workspaces/<name of the folder>`. The projects are inside it, so a single mount gives the container everything, and symbolic links between
  projects are relative (`../../versatile_thermostat/...`). This replaces the host-specific bind mounts that the dev containers of Versatile
  Thermostat and of the dashboard use for each project.
- **Bind mount by default.** `workspaceMount` is the bind mount that VS Code makes by default, written out so that you can change it in
  one place. A bind mount keeps your files on the host: you can use host tools, and `Rebuild Container` loses nothing. Its cost is the speed of
  file access on Windows and macOS. For the best speed, use a named volume (see below).
- **Volumes for what is heavy.** `node_modules` of the dashboard, of its frontend and of the card live on volumes of the container (thousands of
  small files are slow through a bind mount), and so do the pip and npm caches. No host path is involved, and the names are the same on every
  computer.
- **One Python environment.** Home Assistant, the plugins and all the tests run with the Python 3.14 of the image, as in the dev containers of
  Versatile Thermostat and of the dashboard. The version of Home Assistant is the one pinned by `versatile_thermostat/requirements_dev.txt`;
  `vtherm_api` is installed from its submodule, in editable mode.
- **Integrations are linked, not copied.** `.devcontainer/link-components.sh` reads `.gitmodules` and links every
  `<project>/custom_components/<domain>` (and the root of `heating-simulator`) into `config/custom_components`, and the `dist/` of the cards into
  `config/www/community/<card>`. Adding a project needs no change in this script.
- **The dashboard tests use the workspace.** `external/` is not symlinked: no link or mount is created in it. The dashboard finds the
  projects it reads through environment variables, which `devcontainer.json` sets in `containerEnv` (see the list below). HACS, which the
  dashboard tests also read, has no variable here, so the script of the dashboard fetches it into its default location.
  The dashboard pins its own commit of Versatile Thermostat in `external-refs.txt` for its continuous integration. Here its tests run
  against the commit of the submodule, which may be newer.

  Location variables set by the dev container:

  - `VTHERM_VERSATILE_THERMOSTAT_DIR`: `${containerWorkspaceFolder}/versatile_thermostat` (the `versatile_thermostat` submodule).
  - `VTHERM_API_DIR`: `${containerWorkspaceFolder}/vtherm_api` (the `vtherm_api` submodule).

  `VTHERM_HACS_DIR` is not set: the workspace has no `hacs` folder.

### What was left out of the Versatile Thermostat container

- The mounts of `~/.ssh` and `~/.copilot/agents`: they depend on the user. VS Code forwards your SSH agent and git credentials into the container.
- `openspec` and `rtk`, which its Dockerfile installs with `curl | sh`, and the `./container` helper that uses them. Add them to
  `.devcontainer/Dockerfile` if you work with them.
- The personal parts of its `configuration.yaml` (a person, French sensor names) and its saved dashboards.

## Update and pin the projects

```bash
git submodule update --remote versatile_thermostat      # move one project to the head of its branch
git -C vtherm_dashboard checkout my-branch               # or work on a branch in the project itself
git add versatile_thermostat && git commit -m "chore: update versatile_thermostat"   # record the new commit
git submodule update --init --recursive                  # after a pull: bring the projects back to the recorded commits
git submodule status                                     # a "+" in front of a project means it is not at the recorded commit
```

Commit and push inside a project first (in its own repository), then record the new commit in this repository. Never record a commit
that is not pushed: nobody else can fetch it.

## Add a project

1. `git submodule add https://github.com/<owner>/<project>.git <project>` (and `git config -f .gitmodules submodule.<project>.branch <branch>`).
2. Add its folder to `vtherm.code-workspace` (`folders`, `files.exclude`, and the `project` input if it has tests).
3. If it has Python requirements files, add its name to the loop in `.devcontainer/post-create.sh` (`install_requirements`).
4. Add it to `logger` in `.devcontainer/configuration.yaml` and to the table above.
5. Run `bash .devcontainer/link-components.sh`.

## Known problems

### Windows and WSL

- **Line endings.** Bash scripts must have LF. `.gitattributes` makes this repository use LF, but it does not apply to the submodules. With
  `core.autocrlf=true` (the default of Git for Windows), a submodule is checked out with CRLF, which breaks its shell scripts in the
  container. Run `git config --global core.autocrlf input` **before** `git clone --recurse-submodules`.
- **Hundreds of changes in `git status` inside the container.** The files of the submodules have CRLF on disk, while their index has LF, and
  the git of the container does not convert: it sees every file as modified (the same number of lines added and removed). `post-create.sh`
  sets `core.autocrlf=input` in the container, which hides the difference without changing the files. A new terminal may need
  `git config --global core.autocrlf input` if you did not run `post-create.sh`. To get LF on disk too, set `core.autocrlf=input` on
  Windows, then in each submodule: `git rm --cached -r -q . && git reset --hard` (this discards the uncommitted changes of the submodule).
- **"Default interpreter path ... could not be resolved".** A project can name its own interpreter in its `.vscode/settings.json`
  (`vtherm_pellet_stove` names `/workspaces/vtherm_pellet_stove/.venv/bin/python`), and VS Code gives the settings of a folder priority over
  the ones of `vtherm.code-workspace`. `post-create.sh` links that path to the interpreter of the container, without changing the
  project. If the warning stays, run `bash .devcontainer/post-create.sh` and reload the window (**Developer: Reload Window**).
- **Speed.** Docker Desktop reads a Windows folder slowly. Clone this repository into the Linux file system of WSL 2
  (`\\wsl$\<distribution>\...`, or `~/` in a WSL terminal) and open it from there with VS Code, or use a named volume: replace
  `workspaceMount` and `workspaceFolder` as shown in the comment of `devcontainer.json`, then run **Dev Containers: Clone Repository in Container Volume...**
  with the URL of this repository (this clones without the submodules: see the note in *Get started* if `post-create.sh` fails).
- **Symbolic links.** The scripts create links in the workspace (`config/custom_components/...`). Through
  a bind mount of a Windows folder, links made in the container may be unreadable from Windows, or fail. They work in WSL 2 and in a volume.
- **Long paths.** If the clone fails with "Filename too long": `git config --global core.longpaths true`.
- **Permissions.** With a bind mount, git in the container may say "dubious ownership": `post-create.sh` sets `safe.directory` for the
  container only, not for your computer.

### Other

- Plugin tests may need packages that are missing from their requirements files, or a version of Home Assistant that differs from the one
  pinned by Versatile Thermostat. Install what is missing in the container, and fix the requirements file of the project.
- `pytest-homeassistant-custom-component`, which several projects use for their tests, pins the Home Assistant that it was extracted from
  (for example 2026.10.4), and its last release is often older than the one of Versatile Thermostat. `post-create.sh` installs it without
  that pin, so `pip check` reports the difference, and its fixtures come from the older version.
- `auto-tpi-learning-card` commits its `node_modules` and `dist`. The workspace serves its committed `dist/`; to rebuild it, run `npm run build`
  in the project, and expect a large diff.
- The pip and npm caches, and the `node_modules` volumes, are Docker volumes: remove them with `docker volume ls` and
  `docker volume rm` if you need a clean state.
