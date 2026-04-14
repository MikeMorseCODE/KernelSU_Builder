#!/bin/bash

load_sources_json() {
    local sources_file="${1:-sources.yaml}"
    ruby -ryaml -rjson -e 'puts JSON.generate(YAML.safe_load(ARGF.read, aliases: true))' < "$sources_file" 2>/dev/null
}
