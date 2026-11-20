# Requirements Document

## Introduction

The `vtherm_dashboard` project reads the code of other projects (Versatile Thermostat, `vtherm_api` and HACS) from its `external/` folder. Today this folder is filled in three different ways:

- `vtherm_dashboard/.devcontainer/post-create.sh` and `scripts/fetch-external.sh` clone the repositories into `external/` at the references of `external-refs.txt`.
- `/workspaces/vtherm-workspace/.devcontainer/post-create.sh` replaces `external/versatile_thermostat` and `external/vtherm_api` with relative symbolic links (`../../versatile_thermostat`, `../../vtherm_api`) to the sibling submodules of the workspace, then runs `fetch-external.sh` for HACS.
- `vtherm_dashboard/.devcontainer/devcontainer.json` bind-mounts `C:\VS-Projects\versatile_thermostat` and `C:\VS-Projects\vtherm_api` onto `external/`, which is a path specific to one host.

Code and documentation then refer to `external/...` paths: `tests/conftest.py`, `tests/test_hacs_contract.py`, `tests/test_insights_fixtures.py`, `scripts/generate-native-catalogs.ts`, `frontend/test/diagrams.test.ts`, `.devcontainer/start-ha.sh`, `.devcontainer/post-create.sh` (`pip install -e external/vtherm_api`), `eslint.config.ts`, `.gitignore`, `.github/workflows/ci.yml`, and the documents under `docs/`.

This feature removes the `external/` link mechanism. Each external project is located through an environment variable that holds the path of its folder. `devcontainer.json` can set these variables to point at projects that already exist. When a variable is not set, a documented default applies, so that a contributor without a local copy still gets a working environment.

The workspace-level `link-components.sh`, which links the components into `config/custom_components`, is a separate mechanism and is not changed by this feature unless it depends on `external/`.

## Glossary

- **Dashboard_Project**: The `vtherm_dashboard` project, a submodule of the workspace at `/workspaces/vtherm-workspace/vtherm_dashboard`.
- **External_Project**: A project that the Dashboard_Project reads but does not own. The three External_Projects are Versatile Thermostat, `vtherm_api` and HACS.
- **External_Folder**: The `external/` folder at the root of the Dashboard_Project, in which External_Projects are currently cloned or linked.
- **Link_Mechanism**: The set of symbolic links, bind mounts onto `external/`, and clones into `external/` that make External_Projects appear in the External_Folder.
- **Location_Variable**: An environment variable that holds the absolute path of the folder of one External_Project. The names are `VTHERM_VERSATILE_THERMOSTAT_DIR`, `VTHERM_API_DIR` and `VTHERM_HACS_DIR`.
- **Default_Location**: The folder used for an External_Project when its Location_Variable is not set. This is `external/<name>` inside the Dashboard_Project for projects fetched by `fetch-external.sh`. Its exact value is a design decision.
- **Path_Resolver**: The code in each consumer that turns a Location_Variable (or its Default_Location) into the folder of an External_Project. One resolver exists for Python, one for TypeScript, and one for shell scripts.
- **Consumer**: Any script, test, configuration file, or workflow that needs the folder of an External_Project. The Consumers are `tests/conftest.py`, `tests/test_hacs_contract.py`, `tests/test_insights_fixtures.py`, `scripts/generate-native-catalogs.ts`, `frontend/test/diagrams.test.ts`, `.devcontainer/start-ha.sh`, `.devcontainer/post-create.sh`, `scripts/fetch-external.sh`, `.github/workflows/ci.yml`, and `eslint.config.ts`.
- **Workspace_Devcontainer**: The dev container defined in `/workspaces/vtherm-workspace/.devcontainer/`, in which every project is a sibling submodule.
- **Dashboard_Devcontainer**: The dev container defined in `vtherm_dashboard/.devcontainer/`, which can be used on its own.
- **CI**: The GitHub Actions workflow in `vtherm_dashboard/.github/workflows/ci.yml`.
- **Refs_File**: The file `external-refs.txt`, which pins the repository URL and the commit or tag of each fetched External_Project.

## Requirements

### Requirement 1: Locate External Projects Through Environment Variables

**User Story:** As a contributor, I want the location of each External_Project to be given by an environment variable, so that I can point the Dashboard_Project at a copy that I already have.

#### Acceptance Criteria

1. THE Dashboard_Project SHALL define exactly three Location_Variables, one for each External_Project (Versatile Thermostat, `vtherm_api` and HACS), and each Location_Variable SHALL have a name that is unique among the three.
2. WHEN a Location_Variable is set to the path of an existing folder, THE Path_Resolver SHALL return that path as the folder of the External_Project, without checking the folder contents.
3. WHEN a Location_Variable is not set, THE Path_Resolver SHALL return the Default_Location of the External_Project.
4. WHEN a Location_Variable is set to an empty string or to a string made only of whitespace characters, THE Path_Resolver SHALL treat the variable as not set and return the Default_Location of the External_Project.
5. WHEN a Location_Variable holds a relative path, THE Path_Resolver SHALL resolve it against the root of the Dashboard_Project, regardless of the current working directory of the caller, and SHALL return the resulting absolute path.
6. IF a Location_Variable is set to a path that does not exist or that is not a folder, THEN THE Path_Resolver SHALL report an error that names the variable and the path, SHALL NOT fall back to the Default_Location, and SHALL NOT return a path for that External_Project.
7. IF a Location_Variable is not set and the Default_Location of the External_Project is not an existing folder, THEN THE Path_Resolver SHALL report an error that names the variable and the Default_Location, and SHALL NOT return a path for that External_Project.


### Requirement 2: Remove Links and Bind Mounts From external

**User Story:** As a contributor, I want no symbolic link or bind mount to be created in `external/`, so that the Dashboard_Project does not depend on a fixed layout of sibling folders.

#### Acceptance Criteria

1. WHEN the Workspace_Devcontainer post-create script completes with exit code 0, THE Workspace_Devcontainer post-create script SHALL have created 0 symbolic links in the External_Folder.
2. THE Dashboard_Devcontainer configuration SHALL define 0 bind mounts whose target path is the External_Folder or any path inside the External_Folder.
3. THE Dashboard_Devcontainer configuration SHALL contain 0 absolute host paths that begin with a Windows drive letter (for example `C:\VS-Projects`) or with a user home directory prefix (for example `/home/<user>` or `/Users/<user>`).
4. WHEN the Workspace_Devcontainer post-create script finds a symbolic link directly inside the External_Folder, THE Workspace_Devcontainer post-create script SHALL remove the link without removing or modifying its target, and print one message per removed link that contains the link's name.
5. WHEN the Workspace_Devcontainer post-create script finds a regular folder directly inside the External_Folder, THE Workspace_Devcontainer post-create script SHALL leave the folder and all of its contents unchanged and SHALL NOT print a removal message for it.
6. IF the Workspace_Devcontainer post-create script fails to remove a symbolic link in the External_Folder, THEN THE Workspace_Devcontainer post-create script SHALL print a message that contains the link's name and indicates the removal failed, continue processing the remaining entries, and exit with a non-zero exit code.
7. WHEN the Workspace_Devcontainer post-create script runs a second time with no symbolic links in the External_Folder, THE Workspace_Devcontainer post-create script SHALL make no change to the External_Folder contents and exit with code 0.


### Requirement 3: Set Location Variables for the Workspace Devcontainer

**User Story:** As a contributor working in the workspace, I want `devcontainer.json` to set the Location_Variables to the sibling submodules, so that the existing projects are used without cloning them again.

#### Acceptance Criteria

1. THE Workspace_Devcontainer configuration SHALL set `VTHERM_VERSATILE_THERMOSTAT_DIR` to `${containerWorkspaceFolder}/versatile_thermostat` in `containerEnv`.
2. THE Workspace_Devcontainer configuration SHALL set `VTHERM_API_DIR` to `${containerWorkspaceFolder}/vtherm_api` in `containerEnv`.
3. WHERE a folder named `hacs` exists directly under the workspace root at the time the devcontainer configuration is authored, THE Workspace_Devcontainer configuration SHALL set `VTHERM_HACS_DIR` to `${containerWorkspaceFolder}/hacs` in `containerEnv`.
4. WHEN the Workspace_Devcontainer post-create script runs, THE Workspace_Devcontainer post-create script SHALL run `fetch-external.sh` for HACS only if `VTHERM_HACS_DIR` is unset or an empty string.
5. IF `VTHERM_HACS_DIR` is set to a non-empty value, THEN THE Workspace_Devcontainer post-create script SHALL skip the HACS fetch, SHALL leave the folder that `VTHERM_HACS_DIR` points to unmodified, and SHALL complete with exit code 0 for the HACS step.
6. IF `fetch-external.sh` exits with a non-zero code for HACS, THEN THE Workspace_Devcontainer post-create script SHALL exit with a non-zero code and SHALL write an error message to standard error that names HACS as the failed step.
7. THE Workspace_Devcontainer README section SHALL list each Location_Variable that the Workspace_Devcontainer sets, with the variable name and the folder it points to, one entry per variable.


### Requirement 4: Fetch Missing Projects in the Standalone Devcontainer

**User Story:** As a contributor using the Dashboard_Devcontainer alone, I want the External_Projects to be fetched automatically when I give no location, so that the environment works without a local copy.

#### Acceptance Criteria

1. WHEN the Dashboard_Devcontainer post-create script runs and a Location_Variable is not set or is set to an empty string, THE `fetch-external.sh` script SHALL clone the External_Project into its Default_Location at the reference of the Refs_File, or at the value of the matching `*_REF` variable if that variable is set.
2. WHEN a Location_Variable is set to a non-empty value, THE `fetch-external.sh` script SHALL skip the fetch for that External_Project, print the path that is used to standard output, and leave the folder at that path unchanged.
3. WHEN the Default_Location of an External_Project already exists, THE `fetch-external.sh` script SHALL skip the clone and leave the folder contents unchanged. This includes its checked-out reference and any uncommitted changes.
4. WHEN the Dashboard_Devcontainer post-create script runs, THE Dashboard_Devcontainer post-create script SHALL fetch `vtherm_api` by calling `fetch-external.sh`, using the same call that fetches the other External_Projects.
5. WHEN `VERSATILE_THERMOSTAT_REPO`, `VERSATILE_THERMOSTAT_REF`, `HACS_REPO`, `HACS_REF`, `VTHERM_API_REPO` or `VTHERM_API_REF` is set to a non-empty value, THE `fetch-external.sh` script SHALL use that value in place of the matching Refs_File entry, as it does today.
6. IF the clone of an External_Project fails (repository unreachable, reference not found, or no write access to the Default_Location), THEN THE `fetch-external.sh` script SHALL exit with a non-zero exit code, print an error message to standard error that names the External_Project and the failed step, and leave no partially cloned folder at the Default_Location.


### Requirement 5: Use Location Variables in Every Consumer

**User Story:** As a contributor, I want every script and test to use the Location_Variables, so that no consumer assumes that `external/` exists.

#### Acceptance Criteria

1. WHEN `tests/conftest.py`, `tests/test_hacs_contract.py` or `tests/test_insights_fixtures.py` is loaded by pytest, THE Python Path_Resolver SHALL return the folder of each External_Project the file needs, using the value of its Location_Variable if set and non-empty, and otherwise the Default_Location.
2. WHEN `scripts/generate-native-catalogs.ts` or `frontend/test/diagrams.test.ts` starts, THE TypeScript Path_Resolver SHALL return the folder of Versatile Thermostat, using the value of `VTHERM_VERSATILE_THERMOSTAT_DIR` if set and non-empty, and otherwise the Default_Location.
3. WHEN `.devcontainer/start-ha.sh` runs, THE shell Path_Resolver SHALL return the folder of Versatile Thermostat to it. WHEN `.devcontainer/post-create.sh` runs, THE shell Path_Resolver SHALL return the folder of `vtherm_api` to it. Each script SHALL use the value of the matching Location_Variable if set and non-empty, and otherwise the Default_Location.
4. IF the folder of an External_Project does not exist or is not a directory, THEN THE Python tests that need that External_Project SHALL be reported by pytest as skipped, with a skip reason that contains the name of the Location_Variable and the resolved path. THE tests SHALL NOT fail or error because of the missing folder.
5. IF `scripts/generate-native-catalogs.ts` cannot find the translations of Versatile Thermostat in the resolved folder, THEN THE `scripts/generate-native-catalogs.ts` script SHALL write an error message to standard error that contains `VTHERM_VERSATILE_THERMOSTAT_DIR` and the resolved path, SHALL exit with a non-zero exit code, and SHALL leave existing generated catalog files unchanged.
6. THE Dashboard_Project SHALL contain zero occurrences of a hard-coded `external/` path in any Consumer, except in the Default_Location definition inside the Path_Resolver (one definition per Path_Resolver language).
7. THE Dashboard_Project SHALL keep the pytest marker `vtherm` registered, so that `pytest -m vtherm` selects exactly the same set of tests as it selected before the change, and `pytest -m "not vtherm"` excludes exactly that set.


### Requirement 6: Keep CI on Pinned References

**User Story:** As a maintainer, I want the CI to keep testing against pinned references, so that two runs on the same commit test the same code.

#### Acceptance Criteria

1. WHEN the CI starts a run, THE CI SHALL execute `fetch-external.sh` once, before the first test is executed, and SHALL fetch Versatile Thermostat and HACS at the exact references (one reference per repository) listed in the Refs_File committed in the commit under test.
2. IF `fetch-external.sh` exits with a non-zero status, or if a reference listed in the Refs_File for Versatile Thermostat or HACS cannot be resolved, THEN THE CI SHALL fail the run before executing any test, SHALL report an error identifying the repository whose fetch failed, and SHALL NOT fall back to a branch head, a default branch, or a previously cached copy.
3. WHEN the CI starts a run, THE CI SHALL leave every Location_Variable unset (not set, and not set to an empty string) in the environment of `fetch-external.sh`, so that the Default_Location applies.
4. WHEN the CI runs on a commit that has the same Refs_File content as a previous run, THE CI SHALL execute the same set of tests, and each test SHALL have the same pass or fail result as in the previous run, given identical external inputs.
5. WHEN the CI runs on a commit that was passing before the change, THE CI SHALL report 0 failed tests, and the count of executed tests SHALL be greater than or equal to the count executed before the change.


### Requirement 7: Document the Location Variables

**User Story:** As a contributor, I want the documentation to describe the Location_Variables, so that I know how to point the environment at my own copies.

#### Acceptance Criteria

1. THE Dashboard_Project documentation SHALL list, in `docs/contributing/development-environment.md`, every Location_Variable defined by the Dashboard_Project, with one entry per variable that states its name, its meaning in one sentence, and its Default_Location.
2. THE Dashboard_Project documentation SHALL describe, in `docs/contributing/development-environment.md`, how to set a Location_Variable in `devcontainer.json` with `containerEnv`, and SHALL include one example that sets one Location_Variable to an absolute path.
3. THE Dashboard_Project documentation SHALL describe, in `docs/contributing/development-environment.md`, how to mount an existing host folder into the container and how to point a Location_Variable at the container path of that mount, and SHALL include one example that shows the mount and the Location_Variable value together.
4. THE Dashboard_Project documentation SHALL contain no statement that External_Projects are linked or mounted in `external/`, and each statement removed for this reason SHALL be replaced by a statement that names the applicable Location_Variable.
5. THE Dashboard_Project documentation SHALL contain no mention of `external/` in `docs/contributing/ci.md`, `docs/contributing/setting-insights.md`, `docs/contributing/complements.md`, `docs/contributing/config-flow-driver.md`, `docs/plugins/dev-mode.md` and `docs/README.md`, and each mention removed SHALL be replaced by a reference to the applicable Location_Variable.
6. IF a mention of `external/` is found in a file listed in criterion 5 that does not describe the location of an External_Project, THEN THE Dashboard_Project documentation SHALL keep that mention unchanged and the change record SHALL list the file and the line kept.


### Requirement 8: Start Home Assistant and Lint Without external

**User Story:** As a contributor, I want the Home Assistant start script and the linting to work with externally located projects, so that running and checking the code do not depend on `external/`.

#### Acceptance Criteria

1. WHEN `.devcontainer/start-ha.sh` runs and the folder named by `VTHERM_VERSATILE_THERMOSTAT_DIR` contains the Versatile Thermostat integration, THE `.devcontainer/start-ha.sh` script SHALL create a link to that integration inside `config/custom_components` and exit with status 0.
2. IF `VTHERM_VERSATILE_THERMOSTAT_DIR` is unset, empty, or names a folder that does not exist or does not contain the Versatile Thermostat integration, THEN THE `.devcontainer/start-ha.sh` script SHALL print one message to the console that names `VTHERM_VERSATILE_THERMOSTAT_DIR` and the path it checked, SHALL NOT create or modify any link in `config/custom_components` for that integration, and SHALL continue with the remaining steps with the same exit status it returns today for a missing source.
3. WHILE the External_Folder contains an External_Project at its Default_Location, THE `eslint.config.ts` configuration SHALL exclude every file under the External_Folder from linting, so that running ESLint reports 0 errors and 0 warnings originating from files under the External_Folder.
4. WHERE a Location_Variable points to a folder inside the Dashboard_Project, THE `eslint.config.ts` configuration SHALL exclude every file under that folder from linting, so that running ESLint reports 0 errors and 0 warnings originating from files under that folder.
5. THE Dashboard_Project `.gitignore` SHALL contain an entry that causes `git status` to list no files under the External_Folder as untracked or modified.


### Requirement 9: Check the Configuration

**User Story:** As a contributor, I want a smoke check of the configuration, so that a wrong path is found at once and not during a test run.

#### Acceptance Criteria

1. WHEN a contributor runs the check command, THE Dashboard_Project SHALL print one line for each External_Project, containing the Location_Variable name, the resolved folder as an absolute path, and the existence status "exists" or "missing".
2. IF a Location_Variable is set and its resolved folder does not exist or is not a directory, THEN THE check command SHALL print the status "missing" for that External_Project, still check and print all remaining External_Projects, and exit with code 1 after the last line is printed.
3. WHEN every resolved folder exists and is a directory, THE check command SHALL exit with code 0.
4. IF a Location_Variable is not set, THEN THE check command SHALL resolve the folder using the default defined for that Location_Variable, print the resolved folder with the status "exists" or "missing", and exit with code 1 if that folder is missing.
5. WHEN the check command runs, THE check command SHALL complete within 5 seconds and SHALL NOT modify any file or folder.
6. WHEN a Location_Variable has the same value, THE Path_Resolver in Python, THE Path_Resolver in TypeScript and THE Path_Resolver in shell SHALL each return the same absolute folder path, byte for byte. This SHALL hold for values that are absolute paths, relative paths, paths with a trailing slash, paths containing spaces, and the empty value.
