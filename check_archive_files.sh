#!/bin/bash

# Usage: ./compare_filtered_files.sh /path/to/archive.tar.gz /path/to/original_dir "*.wildcard"

set -e

TAR_ARCHIVE="$1"
ORIGINAL_DIR="$2"
WILDCARD="$3"

TMPDIR="/cnc/tmp"
TAR_CONTENTS="${TMPDIR}/tar_contents"
ORIG_HASHES="${TMPDIR}/orig_hashes.txt"
TAR_HASHES="${TMPDIR}/tar_hashes.txt"

# Clean up from previous runs
rm -rf "${TAR_CONTENTS}" "${ORIG_HASHES}" "${TAR_HASHES}"
mkdir -p "${TAR_CONTENTS}"

# Extract all files from tar to tar_contents
tar -xf "$TAR_ARCHIVE" -C "${TAR_CONTENTS}" --strip-components=5

echo "Generating hash list for original files matching '$WILDCARD'..."
(
cd "$ORIGINAL_DIR"
find . -type f -name "$WILDCARD" ! -name "*.tar.gz" | sort | while read -r file; do
    sha256sum "$file"
done
) > "$ORIG_HASHES"

echo "Generating hash list for files from tar extraction..."
(
cd "$TAR_CONTENTS"
find . -type f | sort | while read -r file; do
    sha256sum "$file"
done
) > "$TAR_HASHES"

# Sort both files for comm comparison
ORIG_SORTED="${TMPDIR}/orig_sorted.txt"
TAR_SORTED="${TMPDIR}/tar_sorted.txt"
sort "$ORIG_HASHES" > "$ORIG_SORTED"
sort "$TAR_HASHES"  > "$TAR_SORTED"

# Count lines in each
orig_count=$(wc -l < "$ORIG_SORTED")
tar_count=$(wc -l  < "$TAR_SORTED")

echo "----------------------------------------"
echo "Original file count : $orig_count"
echo "Tar file count      : $tar_count"
echo "----------------------------------------"

# Lines only in original (should be 0)
only_in_orig=$(comm -23 "$ORIG_SORTED" "$TAR_SORTED")

# Lines only in tar (should be 0)
only_in_tar=$(comm -13 "$ORIG_SORTED" "$TAR_SORTED")

# Lines in both
in_both=$(comm -12 "$ORIG_SORTED" "$TAR_SORTED")

# Final verdict
if [[ -z "$only_in_orig" && -z "$only_in_tar" && "$orig_count" -eq "$tar_count" ]]; then
    echo "✅ PASS: All hashes match exactly. Safe to delete original."
    exit 0
else
    echo "❌ FAIL: Hashes do not match. Do NOT delete original."
    exit 1
fi
