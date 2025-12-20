#!/bin/bash
# Fix broken symbolic links (converted to text files on Windows) in sysroot

SYSROOT_DIR="/sysroot"

fix_symlink_file() {
    local file="$1"
    local content=$(cat "$file" 2>/dev/null)
    local dir=$(dirname "$file")

    # Skip if empty or not a small text file
    local size=$(stat -c %s "$file" 2>/dev/null)
    if [ -z "$size" ] || [ "$size" -gt 100 ]; then
        return
    fi

    # Check if content looks like a path or library name (no GROUP keyword)
    if echo "$content" | grep -q "^/" || echo "$content" | grep -q "^lib" || echo "$content" | grep -q "^\.\./"; then
        # Skip if already a valid ld script
        if echo "$content" | grep -qi "GROUP\|OUTPUT_FORMAT"; then
            return
        fi

        echo "Fixing: $file"
        echo "  Old content: $content"
        echo "  New content: GROUP ( $content )"
        echo "GROUP ( $content )" > "$file"
    fi
}

export -f fix_symlink_file

echo "Scanning lib/aarch64-linux-gnu..."
find "$SYSROOT_DIR/lib/aarch64-linux-gnu" -maxdepth 1 -name "*.so*" -type f -size -100c | while read f; do
    fix_symlink_file "$f"
done

echo "Scanning usr/lib/aarch64-linux-gnu..."
find "$SYSROOT_DIR/usr/lib/aarch64-linux-gnu" -maxdepth 1 -name "*.so*" -type f -size -100c | while read f; do
    fix_symlink_file "$f"
done

echo "Done!"
