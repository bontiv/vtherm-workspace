#!/usr/bin/env bash
# Link the custom components and the Lovelace cards of every submodule into the Home Assistant configuration (config/).
# The links are relative, so they work wherever the workspace is mounted. Safe to run again: the links are rebuilt each time.
#
#   custom_components/<domain>/manifest.json  ->  config/custom_components/<domain>
#   manifest.json at the root of a project    ->  config/custom_components/<domain of the manifest>  (heating-simulator)
#   dist/ of a project without integration    ->  config/www/community/<project>                     (the cards)
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p config/custom_components config/www/community
# Remove the links of a previous run: a project that was removed or renamed must not leave a dangling link.
find config/custom_components config/www/community -maxdepth 1 -type l -delete

while read -r _ project; do
    [ -d "$project" ] || continue

    for manifest in "$project"/custom_components/*/manifest.json; do
        [ -f "$manifest" ] || continue
        component_dir="$(dirname "$manifest")"
        ln -sfn "../../$component_dir" "config/custom_components/$(basename "$component_dir")"
        echo "Linked custom component $(basename "$component_dir") ($project)"
    done

    if [ -f "$project/manifest.json" ]; then
        domain="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["domain"])' "$project/manifest.json")"
        ln -sfn "../../$project" "config/custom_components/$domain"
        echo "Linked custom component $domain ($project)"
    fi

    if [ -d "$project/dist" ] && [ ! -d "$project/custom_components" ]; then
        ln -sfn "../../../$project/dist" "config/www/community/$project"
        echo "Linked card $project (served as /local/community/$project/)"
    fi
done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$')
