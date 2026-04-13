#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/sources_json.sh"

# Convert the YAML file to JSON
json=$(load_sources_json "$SCRIPT_DIR/sources.yaml")

# Convert the JSON to a string using jq
json_string=$(echo "$json" | jq -rC tostring)

# Echo the stringified JSON to the GitHub environment variable buildsettings
echo "buildsettings=$json_string" >> $GITHUB_ENV
