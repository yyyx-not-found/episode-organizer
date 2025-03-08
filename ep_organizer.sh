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
#   ./ep_organizer.sh -s <source_directory> -d <destination_directory> -n <new_name> [-l number_length] [-i start_index] [-r] [-t threads]
#
# Arguments:
#   -s <source_directory>      Source directory containing files to organize.
#   -d <destination_directory> Target directory where episode folders are created.
#   -n <new_name>              New name for files inside episode folders (extension excluded).
#   -l <number_length>         (Optional) Number of digits to use for sorting filenames (default: 0).
#   -i <start_index>           (Optional) Starting index for episode folders (default: 1).
#   -r                         (Optional) If present, allows replacing files. If omitted, no files are replaced.
#   -t <threads>               (Optional) Number of parallel copy threads (default: 1).
#
# Example:
#   ./ep_organizer.sh -s "./source" -d "./destination" -n "external" -l 2 -i 5 -r -t 4
#
# Notes:
#   - If a file contains no numbers and NUMBER_LENGTH > 0, the script exits with an error.
#   - If a file's extracted number is shorter than NUMBER_LENGTH, it is zero-padded.
#   - If a file's extracted number is longer than NUMBER_LENGTH, it is truncated from the left.
#   - Multi-threaded mode requires GNU Parallel to be installed.
# =============================================================

# Function to display help message
show_help() {
    echo "Usage: $0 -s <source_directory> -d <destination_directory> -n <new_name> [-l number_length] [-i start_index] [-r] [-t threads]"
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
    echo "  -t <threads>               (Optional) Number of parallel copy threads (default: 1)."
    echo
    echo "Example:"
    echo "  $0 -s ./source -d ./destination -n external -l 2 -i 5 -r -t 4"
    echo
    exit 0
}

# Check if GNU Parallel is installed (only if multi-threading is needed)
check_parallel() {
    if ! command -v parallel &> /dev/null; then
        echo "Error: GNU Parallel is required for multi-threaded operations."
        echo "Please install it using your package manager:"
        echo "  Ubuntu/Debian: sudo apt-get install parallel"
        echo "  CentOS/RHEL: sudo yum install parallel"
        echo "  macOS: brew install parallel"
        exit 1
    fi
}

# Function to display progress bar
display_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r[%${completed}s%${remaining}s] %d%% (%d/%d)" \
           "$(printf '#%.0s' $(seq 1 $completed))" \
           "$(printf ' %.0s' $(seq 1 $remaining))" \
           "$percentage" "$current" "$total"
    
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# Parse command-line arguments
REPLACE=false  # Default: no replace
THREADS=1      # Default: single thread

while getopts "s:d:n:l:i:t:rh" opt; do
    case $opt in
        s) SOURCE_DIR="$OPTARG" ;;
        d) DEST_DIR="$OPTARG" ;;
        n) NEW_NAME="$OPTARG" ;;
        l) NUMBER_LENGTH="$OPTARG" ;;
        i) START_INDEX="$OPTARG" ;;
        t) THREADS="$OPTARG" ;;
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

# Validate that THREADS is a positive integer
if ! [[ "$THREADS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Number of threads must be a positive integer."
    exit 1
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

# Create a temporary log file
LOG_FILE=$(mktemp)
echo "Episode Organizer Log - $(date)" > "$LOG_FILE"
echo "--------------------------------" >> "$LOG_FILE"

# Get list of files with case-insensitive extension matching (excluding directories)
FILES=()
shopt -s nullglob nocaseglob  # Enable case-insensitive matching and handle no matches
for f in "$SOURCE_DIR"/*."$FILE_EXTENSION"; do
    if [ -f "$f" ]; then  # Only include regular files, not directories
        FILES+=("$f")
    fi
done
shopt -u nullglob nocaseglob  # Disable the options after use

TOTAL_FILES=${#FILES[@]}

# Check if there are files in the source directory
if [ "$TOTAL_FILES" -eq 0 ]; then
    echo "Error: No files found in source directory with extension .$FILE_EXTENSION."
    exit 1
fi

echo "Found $TOTAL_FILES .$FILE_EXTENSION files for processing." >> "$LOG_FILE"

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

# Create all required directories in advance
echo "Creating episode directories..." >> "$LOG_FILE"
for ((i=0; i<${#sorted_files[@]}; i++)); do
    EPISODE_INDEX=$((START_INDEX + i))
    EPISODE_DIR="$DEST_DIR/episode_$EPISODE_INDEX"
    mkdir -p "$EPISODE_DIR"
done

# Process files based on thread count
if [ "$THREADS" -eq 1 ]; then
    # Single-threaded copy
    echo "Starting single-threaded copy operation..." >> "$LOG_FILE"
    
    total=${#sorted_files[@]}
    success=0
    skipped=0
    failed=0
    
    for ((i=0; i<${#sorted_files[@]}; i++)); do
        FILE="${sorted_files[i]}"
        EPISODE_INDEX=$((START_INDEX + i))
        EPISODE_DIR="$DEST_DIR/episode_$EPISODE_INDEX"
        DEST_FILE="$EPISODE_DIR/$NEW_NAME.${FILE##*.}"  # Preserve original extension case

        # Display progress
        display_progress $((i+1)) $total

        # Copy or skip the file
        if [[ -f "$DEST_FILE" && !$REPLACE ]]; then
            skipped=$((skipped+1))
            echo "Skipped: $(basename "$FILE") -> $DEST_FILE (already exists)" >> "$LOG_FILE"
        else
            cp "$FILE" "$DEST_FILE"
            if [[ $? -ne 0 ]]; then
                failed=$((failed+1))
                echo "Error copying: $FILE -> $DEST_FILE" >> "$LOG_FILE"
            else
                success=$((success+1))
                echo "Copied: $(basename "$FILE") -> $DEST_FILE" >> "$LOG_FILE"
            fi 
        fi
        
        # Small delay to make progress bar visible
        sleep 0.05
    done
    
    echo >> "$LOG_FILE"
    echo "Copy operation completed: $success files copied, $skipped files skipped, $failed files failed." >> "$LOG_FILE"
else
    # Multi-threaded copy using GNU Parallel
    echo "Starting multi-threaded copy operation with $THREADS threads..." >> "$LOG_FILE"
    check_parallel
    
    # Prepare copy operations
    copy_operations=()
    skipped=0
    
    for ((i=0; i<${#sorted_files[@]}; i++)); do
        FILE="${sorted_files[i]}"
        
        EPISODE_INDEX=$((START_INDEX + i))
        EPISODE_DIR="$DEST_DIR/episode_$EPISODE_INDEX"
        DEST_FILE="$EPISODE_DIR/$NEW_NAME.${FILE##*.}"  # Preserve original extension case
        
        if [[ -f "$DEST_FILE" && !$REPLACE ]]; then
            skipped=$((skipped+1))
            echo "Skipped: $(basename "$FILE") -> $DEST_FILE (already exists)" >> "$LOG_FILE"
        else
            # Add to copy operations with episode index for logging
            copy_operations+=("$FILE|$DEST_FILE|$EPISODE_INDEX")
        fi
    done
    
    # Execute copy operations in parallel if any
    if [ ${#copy_operations[@]} -gt 0 ]; then
        total=${#copy_operations[@]}
        
        echo "Copying $total files with $THREADS parallel threads..." >> "$LOG_FILE"
        
        # Create a script file for parallel to execute
        PARALLEL_SCRIPT=$(mktemp)
        cat > "$PARALLEL_SCRIPT" << 'EOF'
#!/bin/bash
SOURCE="$1"
DEST="$2"
EPISODE="$3"
LOG_FILE="$4"
NEW_NAME="$5"

# Do the copy
cp "$SOURCE" "$DEST"
STATUS=$?

# Log the copy
if [ $STATUS -eq 0 ]; then
    echo "Copied: $(basename "$SOURCE") -> episode_$EPISODE/$NEW_NAME.${SOURCE##*.}" >> "$LOG_FILE"
else
    echo "Error copying: $SOURCE -> $DEST (exit code $STATUS)" >> "$LOG_FILE"
fi

exit $STATUS
EOF
        chmod +x "$PARALLEL_SCRIPT"
        
        # Run parallel jobs with progress display
        for ((i=0; i<${#copy_operations[@]}; i++)); do
            IFS='|' read -r src dst episode <<< "${copy_operations[i]}"
            
            # Execute the script in background
            "$PARALLEL_SCRIPT" "$src" "$dst" "$episode" "$LOG_FILE" "$NEW_NAME" &
            
            # Limit number of parallel jobs
            running_jobs=$(jobs -r | wc -l)
            while [ $running_jobs -ge $THREADS ]; do
                sleep 0.1
                running_jobs=$(jobs -r | wc -l)
            done
            
            # Update progress after each job starts
            display_progress $((i+1)) $total
        done
        
        # Wait for all jobs to finish
        wait
        echo >> "$LOG_FILE"
        
        # Count successful and failed copies
        success=$(grep -c "^Copied:" "$LOG_FILE")
        failed=$(grep -c "^Error copying:" "$LOG_FILE")
        
        echo "All files have been organized into episode folders using $THREADS threads." >> "$LOG_FILE"
        echo "Copy operation completed: $success files copied, $skipped files skipped, $failed files failed." >> "$LOG_FILE"
        
        # Clean up
        rm -f "$PARALLEL_SCRIPT"
    else
        echo "No files to copy (all files already exist or no files in source)." >> "$LOG_FILE"
    fi
fi

echo "Episode organization complete!" >> "$LOG_FILE"

# Display the log contents at the end
echo
echo "=== Episode Organizer Log ==="
cat "$LOG_FILE"
echo "==========================="

# Clean up the temporary log file
rm -f "$LOG_FILE"
