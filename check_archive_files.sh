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
# Generate hashes for matching original files, storing relative paths
(
cd "$ORIGINAL_DIR"
find . -type f -name "$WILDCARD" ! -name "*.tar.gz" | sort | while read -r file; do
    sha256sum "$file"
done
) > "$ORIG_HASHES"

echo "Generating hash list for files from tar extraction..."
# Generate hashes for all files in tar_contents, using relative paths
(
cd "$TAR_CONTENTS"
find . -type f | sort | while read -r file; do
    sha256sum "$file"
done
) > "$TAR_HASHES"

echo "Hashes present in both sets:"
comm -12 <(sort "$ORIG_HASHES") <(sort "$TAR_HASHES")

echo ""
echo "Cleaning up..."
#rm -rf "${TAR_CONTENTS}" "${ORIG_HASHES}" "${TAR_HASHES}"
