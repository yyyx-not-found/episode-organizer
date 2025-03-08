#!/bin/bash

# Test script for episode-organizer with large files
# Creates 50 large text files (256 MB each) and tests single and multi-threaded copying

set -e  # Exit on error

# Configuration
SOURCE_DIR="./test_source"
DEST_DIR_SINGLE="./test_output_single"
DEST_DIR_MULTI="./test_output_multi"
FILE_SIZE_MB=256
NUM_FILES=20
FILE_PREFIX="test_file_"

# Create source directory if it doesn't exist
mkdir -p "$SOURCE_DIR"

echo "=== Episode Organizer Test Script ==="
echo "Creating $NUM_FILES files of size ${FILE_SIZE_MB}MB each..."
echo "Total data size: $((FILE_SIZE_MB * NUM_FILES))MB"

# Create test files with numbering pattern
for i in $(seq -w 1 $NUM_FILES); do
    FILENAME="${FILE_PREFIX}${i}.txt"
    FILE_PATH="$SOURCE_DIR/$FILENAME"
    
    # Skip if file already exists with correct size
    if [ -f "$FILE_PATH" ] && [ $(du -m "$FILE_PATH" | cut -f1) -ge $FILE_SIZE_MB ]; then
        echo -n "."
        continue
    fi
    
    # Create file with dd
    dd if=/dev/urandom of="$FILE_PATH" bs=1M count=$FILE_SIZE_MB status=none
    echo -n "+"
done

echo
echo "All test files created successfully."
echo

# Function to verify files by comparing checksums
verify_files() {
    local source_dir=$1
    local dest_base_dir=$2
    local errors=0
    
    echo "Verifying file integrity with checksums..."
    
    # Loop through source files
    for src_file in "$source_dir"/*; do
        local filename=$(basename "$src_file")
        local src_number=$(echo "$filename" | grep -oE '[0-9]+')
        local episode_num=$((10#$src_number))  # Convert to base-10 integer
        local dest_file="$dest_base_dir/episode_$episode_num/episode.${filename##*.}"
        
        # Calculate checksums
        local src_checksum=$(md5sum "$src_file" | awk '{print $1}')
        local dest_checksum=$(md5sum "$dest_file" | awk '{print $1}')
        
        echo -n "."
        
        # Compare checksums
        if [ "$src_checksum" != "$dest_checksum" ]; then
            echo -e "\nChecksum mismatch: $src_file -> $dest_file"
            echo "  Source MD5: $src_checksum"
            echo "  Dest   MD5: $dest_checksum"
            ((errors++))
        fi
    done
    
    echo
    if [ "$errors" -eq 0 ]; then
        echo "All files verified successfully!"
    else
        echo "Found $errors files with integrity issues!"
    fi
    
    return $errors
}

# Remove existing test output directories
rm -rf "$DEST_DIR_SINGLE" "$DEST_DIR_MULTI"

# Store source files in an array for later verification
source_files=("$SOURCE_DIR"/*)

# Run episode organizer in single-threaded mode
echo "=== Testing single-threaded mode ==="
time ./ep_organizer.sh -s "$SOURCE_DIR" -d "$DEST_DIR_SINGLE" -n "episode" -l 2 -i 1 -t 1
echo

# Verify single-threaded copy integrity
echo "Verifying single-threaded copy integrity..."
verify_files "$SOURCE_DIR" "$DEST_DIR_SINGLE"
single_errors=$?

# Run episode organizer in multi-threaded mode with 4 threads
echo "=== Testing multi-threaded mode (4 threads) ==="
time ./ep_organizer.sh -s "$SOURCE_DIR" -d "$DEST_DIR_MULTI" -n "episode" -l 2 -i 1 -t 4
echo

# Verify multi-threaded copy integrity
echo "Verifying multi-threaded copy integrity..."
verify_files "$SOURCE_DIR" "$DEST_DIR_MULTI"
multi_errors=$?

# Compare results
echo "=== Test Summary ==="
echo "Files in source directory: $(ls -1 "$SOURCE_DIR" | wc -l)"
echo "Files in single-threaded output: $(find "$DEST_DIR_SINGLE" -type f | wc -l)"
echo "Files in multi-threaded output: $(find "$DEST_DIR_MULTI" -type f | wc -l)"

# Verify file sizes in output directories
echo "Verifying file sizes in output directories..."
SINGLE_SIZE=$(du -sh "$DEST_DIR_SINGLE" | awk '{print $1}')
MULTI_SIZE=$(du -sh "$DEST_DIR_MULTI" | awk '{print $1}')
echo "Single-threaded output size: $SINGLE_SIZE"
echo "Multi-threaded output size: $MULTI_SIZE"

# Check if everything matches
if [ "$(find "$DEST_DIR_SINGLE" -type f | wc -l)" -eq "$NUM_FILES" ] && \
   [ "$(find "$DEST_DIR_MULTI" -type f | wc -l)" -eq "$NUM_FILES" ] && \
   [ "$single_errors" -eq 0 ] && [ "$multi_errors" -eq 0 ]; then
    echo -e "\nTest successful! Both modes correctly processed all files with integrity intact."
else
    echo -e "\nTest failed!"
    echo "Single-threaded integrity errors: $single_errors"
    echo "Multi-threaded integrity errors: $multi_errors"
fi