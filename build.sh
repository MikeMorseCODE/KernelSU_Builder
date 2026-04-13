#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/sources_json.sh"

# Get version from GitHub environment variable
version=${VERSION}
KERNEL_DIR="${KERNEL_DIR:-$SCRIPT_DIR/kernel}"

# Check if version is provided
if [ -z "$version" ]
then
    echo "No version specified. No config or build will be executed. Exiting..."
    exit 1
fi

# Convert the YAML file to JSON
json=$(load_sources_json "$SCRIPT_DIR/sources.yaml")

# Check if json is empty
if [ -z "$json" ]
then
    echo "Failed to convert YAML to JSON. Exiting..."
    exit 1
fi

# Parse the JSON file
config_commands=$(echo $json | jq -r --arg version "$version" '.[$version].config[]')
build_commands=$(echo $json | jq -r --arg version "$version" '.[$version].build[]')

# Check if config_commands and build_commands are empty
if [ -z "$config_commands" ] || [ -z "$build_commands" ]
then
    echo "Failed to parse JSON. Exiting..."
    exit 1
fi

# Print the commands that will be executed
echo -e "\033[31mBuild.sh will execute following commands corresponding to ${version}:\033[0m"
echo "$config_commands" | while read -r command; do
    echo -e "\033[32m$command\033[0m"
done
echo "$build_commands" | while read -r command; do
    echo -e "\033[32m$command\033[0m"
done

# Enter the kernel directory
cd "$KERNEL_DIR" || exit 1

# Enable ccache automatically when available (can be disabled with USE_CCACHE=0).
if command -v ccache >/dev/null 2>&1 && [ "${USE_CCACHE:-1}" != "0" ]; then
    export CCACHE_DIR="${CCACHE_DIR:-$PWD/.ccache}"
    export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-20G}"
    export CCACHE_COMPRESS=1
    ccache -M "$CCACHE_MAXSIZE" >/dev/null 2>&1 || true
    extra_make_env='CC="ccache clang" HOSTCC="ccache clang"'
else
    extra_make_env=''
fi

# Execute the config commands
echo "$config_commands" | while read -r command; do
    eval "$command"
done

# Execute the build commands
echo "$build_commands" | while read -r command; do
    if [ -n "${MAKE_JOBS:-}" ]; then
        command=$(echo "$command" | sed -E "s/-j\\$\\(nproc\\)/-j${MAKE_JOBS}/g; s/-j[0-9]+/-j${MAKE_JOBS}/g")
    fi
    eval "$command $extra_make_env"
done
