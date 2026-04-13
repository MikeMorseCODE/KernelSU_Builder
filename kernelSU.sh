#!/bin/bash

source ./lib/sources_json.sh

# Define some colors
GREEN='\033[32m'
RED='\033[31m'
NC='\033[0m' # No Color

# Get version from GitHub environment variable
version=${VERSION}
kernelsu_version=${KERNELSU_VERSION}

# Convert the YAML file to JSON
json=$(load_sources_json sources.yaml)

# Check if json is empty
if [ -z "$json" ]
then
    echo -e "${RED}Failed to convert YAML to JSON. Exiting...${NC}"
    exit 1
fi

# Parse the JSON file to get the kernelSU version corresponding to the VERSION environment variable
kernelSU_version=$(echo $json | jq -r --arg version "$version" '.[$version].kernelSU[]')

# Check if kernelSU_version is empty
if [ -z "$kernelSU_version" ]
then
    echo -e "${RED}Failed to parse JSON. Exiting...${NC}"
    exit 1
fi

# Parse the JSON file to get the commands corresponding to the kernelSU_version
kernelSU_commands=$(echo $json | jq -r --arg version "$kernelSU_version" '.KernelSU.version[$version][]')

# Print the commands that will be executed
echo -e "${GREEN}kernelSU.sh will execute following commands:${NC}"
echo "$kernelSU_commands" | while read -r command; do
    # Replace the placeholder with the actual value
    command=${command//kernelsu-version/$kernelsu_version}
    echo -e "${RED}$command${NC}"
done

# Enter kernel directory
cd kernel

# Execute the commands
echo "$kernelSU_commands" | while read -r command; do
    # Replace the placeholder with the actual value
    command=${command//kernelsu-version/$kernelsu_version}
    eval "$command"
done

# Patch pgtable include mismatch for different kernel trees.
if [ -d "drivers/kernelsu" ]; then
    find drivers/kernelsu -type f \( -name "*.c" -o -name "*.h" \) \
        -exec sed -i -E 's@#include <linux/pgtable.h>@#include <asm/pgtable.h>@g; s@#include "linux/pgtable.h"@#include <asm/pgtable.h>@g' {} +

    if rg -n '#include (<|")linux/pgtable\.h(>|")' drivers/kernelsu >/dev/null 2>&1; then
        echo -e "${RED}Warning: unresolved linux/pgtable.h includes remain in drivers/kernelsu.${NC}"
        rg -n '#include (<|")linux/pgtable\.h(>|")' drivers/kernelsu || true
    fi
fi

# Fix KernelSU fsnotify API mismatch for kernels exposing fsnotify_ops.handle_event.
if [ -f "drivers/kernelsu/manager/pkg_observer.c" ] && [ -f "include/linux/fsnotify_backend.h" ]; then
    if grep -q "handle_event" include/linux/fsnotify_backend.h; then
        sed -i 's/\.handle_inode_event = ksu_handle_inode_event,/.handle_event = ksu_handle_inode_event,/g' drivers/kernelsu/manager/pkg_observer.c
    fi
fi
