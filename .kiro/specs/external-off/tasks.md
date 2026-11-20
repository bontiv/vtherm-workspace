# Implementation Plan: external-off

## Overview

Replace the `external/` link mechanism of `vtherm_dashboard` with three Location_Variables (`VTHERM_VERSATILE_THERMOSTAT_DIR`, `VTHERM_API_DIR`, `VTHERM_HACS_DIR`). The plan first builds the three Path_Resolvers (Python, TypeScript, shell) and the check command, then moves every Consumer onto them, then updates `fetch-external.sh`, the devcontainers, CI and the documentation. Paths below are relative to `/workspaces/vtherm-workspace/vtherm_dashboard` unless stated otherwise. Implementation languages are Python, TypeScript and Bash, as chosen in the design.

## Tasks

- [x] 1. Python resolver and Python consumers
  - [x] 1.1 Create the Python resolver `tests/external_paths.py`
    - Define `Location`, `LOCATIONS` (three entries), `ExternalProjectError`, `locate`, `resolve` and `skip_reason` as in the design
    - Blank (unset, empty, whitespace-only) value selects the default; otherwise `os.path.normpath(os.path.join(root, value))`; no trimming of non-blank values
    - `resolve` raises an error naming the variable and the path when the folder is missing, with no fallback
    - Add `hypothesis` to the Python dev dependencies
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_

  - [ ]* 1.2 Write property tests for the Python resolver in `tests/test_external_paths.py`
    - **Property 1: Blank variable resolves to the default**
    - **Property 2: Set value resolves to a normalized absolute path independent of the working directory**
    - **Property 3: A set variable that is not a folder is an error without fallback**
    - **Property 4: A missing default is an error**
    - Each property is its own test with `max_examples=100` and a `Feature: external-off, Property <n>` comment; also a test that the registry has three unique variable names
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7**

  - [x] 1.3 Move the Python consumers onto the resolver
    - Update `tests/conftest.py`, `tests/test_hacs_contract.py` and `tests/test_insights_fixtures.py` to use `locate` and `skip_reason`; build `requires_vtherm` with the skip reason `<VARIABLE>: <path> is not available`
    - Keep the `vtherm` marker name and selection in `pyproject.toml`; only change its description text
    - Remove every hard-coded `external/` path outside the resolver
    - _Requirements: 5.1, 5.4, 5.6, 5.7_

  - [ ]* 1.4 Write unit tests for the skip behavior and marker
    - Run pytest in a subprocess with a missing folder and check the tests are skipped with a reason containing the variable name and path
    - Check `pytest -m vtherm --collect-only` and `-m "not vtherm"` select complementary sets
    - Add a static test that no Consumer contains a hard-coded `external/` path
    - _Requirements: 5.4, 5.6, 5.7_

- [x] 2. TypeScript resolver and TypeScript consumers
  - [x] 2.1 Create the TypeScript resolver `scripts/external-paths.ts`
    - Export `LOCATIONS`, `locate`, `resolve` and `ExternalProjectError` with the same rule as Python, using `path.resolve(root, value)` and `fs.statSync(...).isDirectory()`
    - Add `fast-check` to the dev dependencies and make sure the test configuration covers `scripts/`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 5.2_

  - [ ]* 2.2 Write property tests for the TypeScript resolver in `scripts/external-paths.test.ts`
    - **Property 1: Blank variable resolves to the default**
    - **Property 2: Set value resolves to a normalized absolute path independent of the working directory**
    - **Property 3: A set variable that is not a folder is an error without fallback**
    - **Property 4: A missing default is an error**
    - Each property is its own test with `numRuns: 100`
    - **Validates: Requirements 1.2, 1.3, 1.4, 1.5, 1.6, 1.7**

  - [x] 2.3 Add `externalIgnores(env, root)` to `eslint.config.ts`
    - Always include `external/**`; add `<relative-path>/**` for each Location_Variable whose resolved folder lies inside the project root and outside `external/`; add nothing for folders outside the root
    - Use the list in the `ignores` entry of the configuration
    - _Requirements: 8.3, 8.4_

  - [ ]* 2.4 Write property test for the ESLint ignore builder in `scripts/external-paths.test.ts`
    - **Property 8: ESLint ignores every folder of a variable that lies inside the project**
    - **Validates: Requirements 8.3, 8.4**

  - [x] 2.5 Move the TypeScript consumers onto the resolver
    - `scripts/generate-native-catalogs.ts`: derive the translations folder from `locate("versatile_thermostat")`; check it before the first write; on a missing folder write `VTHERM_VERSATILE_THERMOSTAT_DIR: <path> has no Versatile Thermostat translations` to stderr and exit 1 without touching existing catalogs
    - `frontend/test/diagrams.test.ts`: use the resolved folder through a relative import of the resolver and make sure the `tsconfig`/vitest include covers it
    - _Requirements: 5.2, 5.5, 5.6_

  - [ ]* 2.6 Write tests for `generate-native-catalogs.ts` with a bad variable
    - Check the stderr text, exit code 1 and that existing catalog files are unchanged
    - _Requirements: 5.5_

- [x] 3. Shell resolver and check command
  - [x] 3.1 Create the shell resolver `scripts/external-paths.sh`
    - Provide `external_variable`, `external_default`, `external_locate` and `external_resolve`, meant to be sourced
    - Blank test with `[[ -z "${value//[[:space:]]/}" ]]`; normalize with `realpath -m -s`; handle absolute values directly; use `$VTHERM_PROJECT_ROOT` or the parent of `scripts/` as root
    - `external_resolve` prints the error on stderr naming variable and path and returns 1
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 5.3_

  - [x] 3.2 Create the check command `scripts/check-external.sh` and the `check:external` npm script
    - Print one line `<VARIABLE> <absolute path> exists|missing` per project in a fixed order, create or modify nothing, print all lines before exiting, exit 1 if any is missing, otherwise 0
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

  - [ ]* 3.3 Write property test for the check command in `tests/test_check_external.py`
    - **Property 6: The check command reports every project and its exit code follows the folders**
    - Also test that it runs in under 5 seconds and leaves the tree unchanged
    - **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5**

  - [ ]* 3.4 Write the cross-language agreement test in `tests/test_external_paths_agreement.py`
    - **Property 5: The three resolvers agree**
    - Run the TypeScript resolver with `node` and the shell resolver with `bash` and compare to Python for absolute, relative, trailing slash, spaces, empty and unset values
    - **Validates: Requirements 5.2, 5.3, 9.6**

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Fetch script, dashboard devcontainer, start script and CI
  - [x] 5.1 Update `external-refs.txt` and `scripts/fetch-external.sh`
    - Add a `vtherm_api <url> main` line to `external-refs.txt`
    - Accept optional project names as arguments; for each project: skip with a stdout message naming the path when its Location_Variable is non-blank; skip with `exists, left as it is` when the default folder exists; otherwise clone into `external/.<name>.tmp.$$` and rename on success
    - Keep `*_REPO` and `*_REF` overrides; on failure remove the temporary folder, print `<name>: <step> failed (<url> at <ref>)` to stderr, continue with the other projects and exit 1 at the end
    - Source `scripts/external-paths.sh` for path computation
    - _Requirements: 4.1, 4.2, 4.3, 4.5, 4.6_

  - [ ]* 5.2 Write tests for `fetch-external.sh` with local `file://` repositories
    - Cover clone at pinned ref, `*_REF`/`*_REPO` override, variable set (path printed, folder unchanged), existing folder with uncommitted changes untouched, unreachable URL and unknown ref (no partial folder, stderr names the project)
    - _Requirements: 4.1, 4.2, 4.3, 4.5, 4.6_

  - [x] 5.3 Wire the dashboard devcontainer, start script and CI
    - `.devcontainer/devcontainer.json`: remove the two `C:\VS-Projects` bind mounts and any host path
    - `.devcontainer/post-create.sh`: replace the direct `git clone` of `vtherm_api` with `bash scripts/fetch-external.sh`, then `pip install -e "$(external_locate vtherm_api)"`
    - `.devcontainer/start-ha.sh`: source the shell resolver, link `<folder>/custom_components/versatile_thermostat`; when missing print one line naming `VTHERM_VERSATILE_THERMOSTAT_DIR` and the checked path, create nothing, keep the current exit status
    - `.github/workflows/ci.yml`: call `bash scripts/fetch-external.sh versatile_thermostat hacs`, set no Location_Variable, reword the `external/` comment
    - Keep `/external/` in `.gitignore`
    - _Requirements: 2.2, 2.3, 4.4, 5.3, 6.1, 6.2, 6.3, 8.1, 8.2, 8.5_

  - [ ]* 5.4 Write static and example tests for the wiring
    - Dashboard `devcontainer.json` has no mount onto `external` and no Windows drive or home path; dashboard `post-create.sh` has no `git clone` and calls `fetch-external.sh`; CI has no Location_Variable; `git check-ignore external/hacs` succeeds
    - `start-ha.sh` against a temporary tree with a stubbed `hass`: link created, or skipped with the message and unchanged exit status
    - _Requirements: 2.2, 2.3, 4.4, 6.3, 8.1, 8.2, 8.5_

- [x] 6. Workspace devcontainer
  - [x] 6.1 Update the workspace devcontainer in `/workspaces/vtherm-workspace/.devcontainer/`
    - `devcontainer.json`: add to `containerEnv` `VTHERM_VERSATILE_THERMOSTAT_DIR=${containerWorkspaceFolder}/versatile_thermostat` and `VTHERM_API_DIR=${containerWorkspaceFolder}/vtherm_api`; do not set `VTHERM_HACS_DIR` because the workspace has no `hacs` folder
    - `post-create.sh`: replace the symlink creation with `cleanup_external_links` (remove symlinks only, print `Removed link <name>`, print a failure message and return non-zero when `rm` fails, leave regular entries silent and unchanged); run `fetch-external.sh hacs` only when `VTHERM_HACS_DIR` is blank; on failure print an error naming HACS to stderr, continue, and exit non-zero at the end
    - _Requirements: 2.1, 2.4, 2.5, 2.6, 2.7, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [ ]* 6.2 Write property test for the link cleanup in `tests/test_cleanup_external_links.py`
    - **Property 7: Link cleanup removes links only and is idempotent**
    - Generate mixes of symlinks (to files, folders, dangling) and regular entries
    - **Validates: Requirements 2.1, 2.4, 2.5, 2.7**

  - [ ]* 6.3 Write example tests for the workspace post-create script
    - Stub `fetch-external.sh`; cover `VTHERM_HACS_DIR` unset, set and failing; a read-only parent folder makes link removal fail; check the `containerEnv` values in the workspace `devcontainer.json`
    - _Requirements: 2.6, 3.1, 3.2, 3.4, 3.5, 3.6_

- [x] 7. Documentation
  - [x] 7.1 Update the dashboard documentation
    - `docs/contributing/development-environment.md`: table of the three variables (name, one-sentence meaning, Default_Location), a `containerEnv` example with an absolute path, a mount example with the matching variable value, a description of `npm run check:external`, and the rule that relative values resolve against the project root
    - Replace the mentions of `external/` that describe a project location by a reference to the variable in `ci.md`, `setting-insights.md`, `complements.md`, `config-flow-driver.md`, `docs/plugins/dev-mode.md` and `docs/README.md`; keep other mentions and list file and line in the change record
    - Update the `vtherm` marker description in `pyproject.toml` if still mentioning `external/`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

  - [x] 7.2 Update the workspace README at `/workspaces/vtherm-workspace/README.md`
    - List each Location_Variable that the Workspace_Devcontainer sets, one entry per variable with the folder it points to
    - _Requirements: 3.7_

  - [ ]* 7.3 Write documentation tests
    - Check every registry variable appears in `development-environment.md`, the listed docs contain no `external/`, and the workspace README lists each `containerEnv` variable
    - _Requirements: 3.7, 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 8. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Property tests validate the universal correctness properties of the design; example tests cover the criteria that are not properties
- CI behavior on GitHub (requirements 6.4 and 6.5) is checked by running the workflow once after the change, not by an automated test

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "3.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "2.2", "2.3", "2.5", "3.2"] },
    { "id": 2, "tasks": ["1.4", "2.4", "2.6", "3.3", "3.4"] },
    { "id": 3, "tasks": ["4"] },
    { "id": 4, "tasks": ["5.1", "6.1"] },
    { "id": 5, "tasks": ["5.2", "5.3", "6.2", "6.3", "7.1", "7.2"] },
    { "id": 6, "tasks": ["5.4", "7.3"] },
    { "id": 7, "tasks": ["8"] }
  ]
}
```
