#!/bin/bash

source ./lib/sources_json.sh

# Get version from GitHub environment variable
version=${VERSION}

# Check if version is provided
if [ -z "$version" ]
then
    echo "No version specified. No kernel or clang will be cloned. Exiting..."
    exit 1
fi

# Convert the YAML file to JSON
json=$(load_sources_json sources.yaml)

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
echo "$kernel_commands" | while read -r command; do
    echo -e "\033[32m$command\033[0m"
done
echo "$clang_commands" | while read -r command; do
    echo -e "\033[32m$command\033[0m"
done

# Clone the kernel and append clone path to the command
echo "$kernel_commands" | while read -r command; do
    eval "$command kernel"
done

# Clone the clang and append clone path to the command
echo "$clang_commands" | while read -r command; do
    eval "$command kernel/clang"
done
