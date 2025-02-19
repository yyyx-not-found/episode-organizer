#!/bin/bash

# =============================================================
# Script Name: Episode Organizer
# Author: Yixian Yang
# Email: yixiany2@illinois.edu
# Description:
#   This script organizes media files (default: .mp4) from a source directory 
#   into episode folders named `episode_X` starting from a user-defined index.
#   Each file is renamed to a specified name while preserving its extension.
#
#   Sorting Rules:
#   - If NUMBER_LENGTH > 0, the script extracts the last `NUMBER_LENGTH` digits 
#     from numbers found in filenames for numerical sorting.
#   - If NUMBER_LENGTH = 0, filenames are sorted alphabetically.
#
#   File Replacement:
#   - By default, the script does **not** overwrite files.
#   - If `-r` is provided, existing files will be replaced.
#
# Usage:
#   ./ep_organizer.sh -s <source_directory> -d <destination_directory> -n <new_name> [-l number_length] [-i start_index] [-r]
#
# Arguments:
#   -s <source_directory>      Source directory containing files to organize.
#   -d <destination_directory> Target directory where episode folders are created.
#   -n <new_name>              New name for files inside episode folders (extension excluded).
#   -l <number_length>         (Optional) Number of digits to use for sorting filenames (default: 0).
#   -i <start_index>           (Optional) Starting index for episode folders (default: 1).
#   -r                         (Optional) If present, allows replacing files. If omitted, no files are replaced.
#
# Example:
#   ./ep_organizer.sh -s "./source" -d "./destination" -n "external" -l 2 -i 5 -r
#
# Notes:
#   - If a file contains no numbers and NUMBER_LENGTH > 0, the script exits with an error.
#   - If a file's extracted number is shorter than NUMBER_LENGTH, it is zero-padded.
#   - If a file's extracted number is longer than NUMBER_LENGTH, it is truncated from the left.
# =============================================================

# Function to display help message
show_help() {
    echo "Usage: $0 -s <source_directory> -d <destination_directory> -n <new_name> [-l number_length] [-i start_index] [-r]"
    echo
    echo "Organizes files into numbered episode folders (episode_X, episode_X+1, etc.) starting from a given index."
    echo
    echo "Arguments:"
    echo "  -s <source_directory>      Source directory containing files to organize."
    echo "  -d <destination_directory> Target directory where episode folders are created."
    echo "  -n <new_name>              New name for files inside episode folders (extension excluded)."
    echo "  -l <number_length>         (Optional) Number of digits to use for sorting filenames (default: 0)."
    echo "  -i <start_index>           (Optional) Starting index for episode folders (default: 1)."
    echo "  -r                         (Optional) If present, allows replacing files. If omitted, no files are replaced."
    echo
    echo "Example:"
    echo "  $0 -s ./source -d ./destination -n external -l 2 -i 5 -r"
    echo
    exit 0
}

# Parse command-line arguments
REPLACE=false  # Default: no replace

while getopts "s:d:n:l:i:rh" opt; do
    case $opt in
        s) SOURCE_DIR="$OPTARG" ;;
        d) DEST_DIR="$OPTARG" ;;
        n) NEW_NAME="$OPTARG" ;;
        l) NUMBER_LENGTH="$OPTARG" ;;
        i) START_INDEX="$OPTARG" ;;
        r) REPLACE=true ;;  # If -r is provided, enable replacement
        h) show_help ;;
        *) echo "Invalid option: -$OPTARG" >&2; show_help ;;
    esac
done

# Ensure required arguments are provided
if [[ -z "$SOURCE_DIR" || -z "$DEST_DIR" || -z "$NEW_NAME" ]]; then
    echo "Error: Missing required arguments."
    show_help
fi

# Set default values for optional arguments
NUMBER_LENGTH="${NUMBER_LENGTH:-0}"  # Default: 0 (alphabetical sorting)
START_INDEX="${START_INDEX:-1}"      # Default: 1 (start from episode_1)
FILE_EXTENSION="mp4"

# Function to extract numbers from filenames
extract_number() {
    local filename=$(basename "$1")
    local num=""
    
    if [[ "$NUMBER_LENGTH" -gt 0 ]]; then
        # Extract all numbers from the filename
        all_numbers=($(echo "$filename" | grep -oE '[0-9]+'))  # Convert to array

        # If no numbers are found, exit with an error
        if [[ ${#all_numbers[@]} -eq 0 ]]; then
            echo "Error: No numbers found in filename '$filename'." >&2
            exit 1
        fi

        # Build the number using the last few extracted numbers until NUMBER_LENGTH is met
        local combined=""
        for ((i=${#all_numbers[@]}-1; i>=0; i--)); do
            combined="${all_numbers[i]}$combined"
            if [[ ${#combined} -ge "$NUMBER_LENGTH" ]]; then
                break
            fi
        done

        # Ensure `combined` is exactly `NUMBER_LENGTH` characters
        if [[ ${#combined} -lt "$NUMBER_LENGTH" ]]; then
            # Pad with leading zeros if shorter
            while [[ ${#combined} -lt "$NUMBER_LENGTH" ]]; do
                combined="0$combined"
            done
        elif [[ ${#combined} -gt "$NUMBER_LENGTH" ]]; then
            # Truncate from the left if longer
            combined=${combined: -$NUMBER_LENGTH}
        fi

        num=$combined  # Use the processed number
    else
        num=""  # If NUMBER_LENGTH=0, allow alphabetical sorting
    fi

    echo "$num"
}

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory does not exist."
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Get list of files (excluding directories)
FILES=("$SOURCE_DIR"/*."$FILE_EXTENSION")
TOTAL_FILES=${#FILES[@]}

# Check if there are files in the source directory
if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "Error: No files found in source directory."
    exit 1
fi

# Sort files numerically by extracted number
if [[ "$NUMBER_LENGTH" -eq 0 ]]; then
    # Alphabetical sorting
    IFS=$'\n' sorted_files=($(printf "%s\n" "${FILES[@]}" | sort))
else
    # Numeric sorting based on extracted numbers
    IFS=$'\n' sorted_files=($(for file in "${FILES[@]}"; do
        num=$(extract_number "$file")
        echo "$num $file"
    done | sort -n | awk '{print $2}'))
fi
unset IFS

# Move and rename files
for ((i=0; i<${#sorted_files[@]}; i++)); do
    FILE="${sorted_files[i]}"
    EPISODE_INDEX=$((START_INDEX + i))
    EPISODE_DIR="$DEST_DIR/episode_$EPISODE_INDEX"

    mkdir -p "$EPISODE_DIR"

    DEST_FILE="$EPISODE_DIR/$NEW_NAME.$FILE_EXTENSION"

    if [[ -f "$DEST_FILE" && "$REPLACE" == false ]]; then
        echo "Warning: $NEW_NAME.$FILE_EXTENSION already exists in $EPISODE_DIR, skipping."
    else
        cp "$FILE" "$DEST_FILE"
        echo "Info: Copied "$FILE" to "$DEST_FILE"."
    fi
done

echo "All files have been organized into episode folders."
