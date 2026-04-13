#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/sources_json.sh"

# Get version from GitHub environment variable
version=${VERSION}
KERNEL_DIR="${KERNEL_DIR:-$SCRIPT_DIR/kernel}"
CLANG_DIR="${CLANG_DIR:-$KERNEL_DIR/clang}"

# Check if version is provided
if [ -z "$version" ]
then
    echo "No version specified. No kernel or clang will be cloned. Exiting..."
    exit 1
fi

# Convert the YAML file to JSON
json=$(load_sources_json "$SCRIPT_DIR/sources.yaml")

if [ -z "$json" ]
then
    echo "Failed to convert YAML to JSON. Exiting..."
    exit 1
fi

# Parse the JSON file
kernel_commands=$(echo $json | jq -r --arg version "$version" '.[$version].kernel[]')
clang_commands=$(echo $json | jq -r --arg version "$version" '.[$version].clang[]')

# Print the commands that will be executed
echo -e "\033[31mClone.sh will execute following commands corresponding to ${version}:\033[0m"
while read -r command; do
    echo -e "\033[32m$command\033[0m"
done <<< "$kernel_commands"
while read -r command; do
    echo -e "\033[32m$command\033[0m"
done <<< "$clang_commands"

# Clone the kernel and append clone path to the command
if [ -d "$KERNEL_DIR/.git" ]; then
    echo -e "\033[33mkernel source already exists, skipping clone.\033[0m"
else
    while read -r command; do
        eval "$command \"$KERNEL_DIR\""
    done <<< "$kernel_commands"
fi

# Clone the clang and append clone path to the command
if [ -d "$CLANG_DIR/.git" ]; then
    echo -e "\033[33mclang toolchain already exists, skipping clone.\033[0m"
else
    while read -r command; do
        eval "$command \"$CLANG_DIR\""
    done <<< "$clang_commands"
fi
