#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/sources_json.sh"

# Define some colors
GREEN='\033[32m'
RED='\033[31m'
NC='\033[0m' # No Color

# Get version from GitHub environment variable
version=${VERSION}
kernelsu_version=${KERNELSU_VERSION}
KERNEL_DIR="${KERNEL_DIR:-$SCRIPT_DIR/kernel}"

# Convert the YAML file to JSON
json=$(load_sources_json "$SCRIPT_DIR/sources.yaml")

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
while read -r command; do
    # Replace the placeholder with the actual value
    command=${command//kernelsu-version/$kernelsu_version}
    echo -e "${RED}$command${NC}"
done <<< "$kernelSU_commands"

# Enter kernel directory
cd "$KERNEL_DIR" || exit 1

# Execute the commands
while read -r command; do
    # Replace the placeholder with the actual value
    command=${command//kernelsu-version/$kernelsu_version}
    eval "$command"
done <<< "$kernelSU_commands"

# Patch pgtable include mismatch for different kernel trees.
if [ -d "drivers/kernelsu" ]; then
    find drivers/kernelsu -type f \( -name "*.c" -o -name "*.h" \) \
        -exec sed -i -E 's@#include[[:space:]]*<linux/pgtable.h>@#include <asm/pgtable.h>@g; s@#include[[:space:]]*"linux/pgtable.h"@#include <asm/pgtable.h>@g' {} +

    if command -v rg >/dev/null 2>&1; then
        pgtable_check_cmd='rg -n "#include (<|\")linux/pgtable\\.h(>|\")" drivers/kernelsu'
    else
        pgtable_check_cmd='grep -RnsE "#include[[:space:]]*(<|\")linux/pgtable\\.h(>|\")" drivers/kernelsu'
    fi
    if eval "$pgtable_check_cmd" >/dev/null 2>&1; then
        echo -e "${RED}Warning: unresolved linux/pgtable.h includes remain in drivers/kernelsu.${NC}"
        eval "$pgtable_check_cmd" || true
    fi
fi

# Some kernels do not provide include/linux/pgtable.h; add a shim to keep older KernelSU sources building.
if [ ! -f "include/linux/pgtable.h" ] && [ -f "include/asm-generic/pgtable.h" -o -f "arch/arm64/include/asm/pgtable.h" ]; then
    mkdir -p include/linux
    cat > include/linux/pgtable.h <<'EOF'
#ifndef _LINUX_PGTABLE_H
#define _LINUX_PGTABLE_H
#include <asm/pgtable.h>
#endif
EOF
fi

# Some kernels miss SECCOMP_ARCH_NATIVE_NR; provide a compatibility fallback for KernelSU seccomp cache.
if [ -f "drivers/kernelsu/infra/seccomp_cache.c" ]; then
    if [ ! -f "include/linux/seccomp.h" ] || ! grep -q "SECCOMP_ARCH_NATIVE_NR" include/linux/seccomp.h; then
        if ! grep -q "KSU_SECCOMP_ARCH_NATIVE_NR_FALLBACK" drivers/kernelsu/infra/seccomp_cache.c; then
            tmp_file="$(mktemp)"
            cat > "$tmp_file" <<'EOF'
#ifndef SECCOMP_ARCH_NATIVE_NR
#define KSU_SECCOMP_ARCH_NATIVE_NR_FALLBACK
#ifdef CONFIG_COMPAT
#define SECCOMP_ARCH_NATIVE_NR 2
#else
#define SECCOMP_ARCH_NATIVE_NR 1
#endif
#endif

EOF
            cat drivers/kernelsu/infra/seccomp_cache.c >> "$tmp_file"
            mv "$tmp_file" drivers/kernelsu/infra/seccomp_cache.c
        fi
    fi
fi

# Fix KernelSU fsnotify API mismatch for kernels exposing fsnotify_ops.handle_event.
if [ -f "drivers/kernelsu/manager/pkg_observer.c" ] && [ -f "include/linux/fsnotify_backend.h" ]; then
    if grep -q "handle_event" include/linux/fsnotify_backend.h; then
        if ! grep -q "ksu_handle_event_bridge(struct fsnotify_group \\*group" drivers/kernelsu/manager/pkg_observer.c; then
            sed -i '1i static int ksu_handle_event_bridge(struct fsnotify_group *group, struct inode *to_tell, u32 mask, const void *data, int data_type, const struct qstr *file_name, u32 cookie, struct fsnotify_iter_info *iter_info);' drivers/kernelsu/manager/pkg_observer.c
        fi
        sed -i 's/\.handle_inode_event = ksu_handle_inode_event,/.handle_event = ksu_handle_event_bridge,/g; s/\.handle_event = ksu_handle_inode_event,/.handle_event = ksu_handle_event_bridge,/g' drivers/kernelsu/manager/pkg_observer.c
        if ! grep -q "Compatibility bridge for kernels using fsnotify_ops.handle_event" drivers/kernelsu/manager/pkg_observer.c; then
            cat >> drivers/kernelsu/manager/pkg_observer.c <<'EOF'

/* Compatibility bridge for kernels using fsnotify_ops.handle_event. */
static int ksu_handle_event_bridge(struct fsnotify_group *group,
                                   struct inode *to_tell, u32 mask,
                                   const void *data, int data_type,
                                   const struct qstr *file_name, u32 cookie,
                                   struct fsnotify_iter_info *iter_info)
{
    return 0;
}
EOF
        fi
    fi
fi

# Backport helpers for older task_work/sched APIs used by KernelSU allowlist.
if [ -f "drivers/kernelsu/policy/allowlist.c" ]; then
    if ! grep -q "linux/sched/task.h" drivers/kernelsu/policy/allowlist.c; then
        sed -i '1i #include <linux/sched/task.h>' drivers/kernelsu/policy/allowlist.c
    fi
    if ! grep -q "KSU_TWA_RESUME_FALLBACK" drivers/kernelsu/policy/allowlist.c; then
        tmp_file="$(mktemp)"
        cat > "$tmp_file" <<'EOF'
#ifndef TWA_RESUME
#define KSU_TWA_RESUME_FALLBACK
#define TWA_RESUME 0
#endif

EOF
        cat drivers/kernelsu/policy/allowlist.c >> "$tmp_file"
        mv "$tmp_file" drivers/kernelsu/policy/allowlist.c
    fi
fi
