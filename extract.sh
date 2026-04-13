#!/bin/bash

source ./lib/sources_json.sh

# Convert the YAML file to JSON
json=$(load_sources_json sources.yaml)

# Convert the JSON to a string using jq
json_string=$(echo "$json" | jq -rC tostring)

# Echo the stringified JSON to the GitHub environment variable buildsettings
echo "buildsettings=$json_string" >> $GITHUB_ENV
