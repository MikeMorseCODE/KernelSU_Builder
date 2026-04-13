#!/bin/bash

set -euo pipefail

TARGET="drivers/kernelsu/manager/pkg_observer.c"

if [ ! -f "$TARGET" ]; then
    echo "[kernelsu_compat] skip: $TARGET not found"
    exit 0
fi

add_include_if_missing() {
    local header="$1"
    if ! grep -Fq "$header" "$TARGET"; then
        sed -i "1i ${header}" "$TARGET"
        echo "[kernelsu_compat] added: ${header}"
    fi
}

# KernelSU's pkg_observer may require explicit includes on some older trees.
add_include_if_missing "#include <linux/types.h>"
add_include_if_missing "#include <linux/fs.h>"
add_include_if_missing "#include <linux/dcache.h>"
add_include_if_missing "#include <linux/fsnotify_backend.h>"

echo "[kernelsu_compat] done"
