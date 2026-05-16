#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERSION="$(grep '^version=' "$ROOT_DIR/module.prop" | head -n1 | cut -d'=' -f2 | xargs)"

if [[ -z "$VERSION" ]]; then
    echo "ERROR: Could not read version from module.prop"
    exit 1
fi

echo "Building Universal GMS Doze v$VERSION"

# Shared files
SHARED_FILES=(
    "META-INF"
    "gmsc"
    "LICENSE"
    "uninstall.sh"
    "README.md"
    "changelog.md"
)

# Normal build files
NORMAL_FILES=(
    "customize.sh"
    "post-fs-data.sh"
    "service.sh"
    "module.prop"
    "module.json"
)

# Debug file mapping
declare -A DEBUG_FILE_MAP=(
    ["customize-debug.sh"]="customize.sh"
    ["post-fs-data-debug.sh"]="post-fs-data.sh"
    ["service-debug.sh"]="service.sh"
    ["module-debug.prop"]="module.prop"
    ["module-debug.json"]="module.json"
)

# Convert CRLF -> LF
convert_line_endings() {
    local dir="$1"

    find "$dir" -type f -name "*.sh" | while read -r file; do
        sed -i 's/\r$//' "$file"
    done
}

new_build() {
    local suffix="$1"
    local is_debug="$2"

    local build_dir
    build_dir="$(mktemp -d)"

    local zip_name
    if [[ -n "$suffix" ]]; then
        zip_name="gms_${VERSION}-${suffix}.zip"
    else
        zip_name="gms_${VERSION}.zip"
    fi

    local zip_path="$ROOT_DIR/$zip_name"

    rm -f "$zip_path"

    echo "Creating $zip_name"

    # Shared files
    for file in "${SHARED_FILES[@]}"; do
        local src="$ROOT_DIR/$file"

        if [[ -e "$src" ]]; then
            cp -r "$src" "$build_dir/"
        else
            echo "  [WARN] Shared file not found: $file"
        fi
    done

    # webroot handling
    local webroot_src="$ROOT_DIR/webroot"

    if [[ -d "$webroot_src" ]]; then
        cp -r "$webroot_src" "$build_dir/"

        local webroot_dst="$build_dir/webroot"
        local debug_index="$webroot_dst/index-debug.html"
        local main_index="$webroot_dst/index.html"

        if [[ "$is_debug" == "true" ]]; then
            if [[ -f "$debug_index" ]]; then
                cp "$debug_index" "$main_index"
                echo "  [OK] webroot/index.html <- index-debug.html"
            else
                echo "  [WARN] webroot/index-debug.html not found"
            fi
        fi

        rm -f "$debug_index"
    else
        echo "  [WARN] webroot directory not found"
    fi

    # Build-specific files
    if [[ "$is_debug" == "true" ]]; then
        for src_name in "${!DEBUG_FILE_MAP[@]}"; do
            dst_name="${DEBUG_FILE_MAP[$src_name]}"

            local src="$ROOT_DIR/$src_name"
            local dst="$build_dir/$dst_name"

            if [[ -f "$src" ]]; then
                cp "$src" "$dst"
            else
                echo "  [WARN] File not found: $src_name"
            fi
        done
    else
        for file in "${NORMAL_FILES[@]}"; do
            local src="$ROOT_DIR/$file"

            if [[ -f "$src" ]]; then
                cp "$src" "$build_dir/$file"
            else
                echo "  [WARN] File not found: $file"
            fi
        done
    fi

    # Normalize line endings
    convert_line_endings "$build_dir"

    # Create zip
    (
        cd "$build_dir"
        zip -qr "$zip_path" .
    )

    # Cleanup
    rm -rf "$build_dir"

    local size
    size="$(du -h "$zip_path" | cut -f1)"

    echo "  [OK] $zip_name ($size)"
}

echo
echo "Normal build..."
new_build "" "false"

echo
echo "Debug build..."
new_build "debug" "true"

echo
echo "Done!"