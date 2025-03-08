# Episode Organizer Script

Automatically organize and rename MP4 files into structured episode folders with multi-threading support.

## Workflow

1. Collect data using cameras.  
2. Manually remove mapping and calibration videos from your collection.
3. Select all `.mp4` files and copy them into a single source directory.  
4. Run the script to organize the files into episode folders.

## Features

### Intelligent Sorting

- **Numerical Sorting**: Extract and sort by numbers in filenames (with configurable digit length)
- **Alphabetical Fallback**: If no numerical sorting is specified, files are sorted alphabetically

### Performance Options

- **Multi-threaded Operation**: Process files in parallel for faster organization
- **Single-threaded Mode**: Traditional sequential processing for simpler operations

### File Management

- **Skip Existing Files**: By default, never overwrite destination files
- **Replace Option**: Optional flag to allow overwriting existing files
- **Case-insensitive Matching**: Works with any case variations of file extensions

## Usage

```bash
./ep_organizer.sh -s <source_directory> -d <destination_directory> -n <new_name> [-l number_length] [-i start_index] [-r] [-t threads]
```

### Arguments

| Flag | Description |
|------|-------------|
| `-s` | Source directory containing `.mp4` files. |
| `-d` | Destination directory for episode folders. |
| `-n` | New filename inside episode folders (no need to add file extension). |
| `-l` | (Optional) Digits to use for sorting filenames (default: 0 - alphabetical). |
| `-i` | (Optional) Start index for episode folders (default: `1`). |
| `-r` | (Optional) If present, allows replacing existing files. |
| `-t` | (Optional) Number of parallel copy threads (default: `1`). |

## Examples

### Basic Usage

```bash
./ep_organizer.sh -s ./source -d ./destination -n external -l 2 -i 1
```

This organizes files using the last 2 digits from each filename for sorting, starting from episode_1.

### With Multi-threading

```bash
./ep_organizer.sh -s ./source -d ./destination -n external -l 2 -i 1 -r -t 4
```

This uses 4 threads for faster copying and allows replacing existing files.

### Result Structure

```
<destination_directory>/
├── episode_1/
│   ├── <new_name>.mp4  # (first sorted file)
├── episode_2/
│   ├── <new_name>.mp4  # (second sorted file)
└── ...
```

## How Sorting Works

1. **When `-l` is set to 0 (default):** Files are sorted alphabetically
2. **When `-l` is set to a positive number:**
   - The script extracts all numbers from each filename
   - It takes the last N digits (where N is the value of `-l`)
   - If a filename has fewer digits than required, it's zero-padded from the left
   - If a filename has more digits than required, it's truncated from the left

## Installation

```bash
git clone https://github.com/yyyx-not-found/episode-organizer.git
cd episode-organizer
chmod +x ep_organizer.sh
```

### Multi-threading Requirements

For multi-threaded operation, GNU Parallel must be installed:

```bash
# Ubuntu/Debian
sudo apt-get install parallel

# CentOS/RHEL
sudo yum install parallel

# macOS
brew install parallel
```

## License

This project is licensed under the MIT License.

## Contact

GitHub: [Profile](https://github.com/yyyx-not-found)  
Email: yixiany2@illinois.edu
