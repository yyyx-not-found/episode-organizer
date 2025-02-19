# Episode Organizer Script

Automatically organize and rename MP4 files into structured episode folders.

## Workflow

1. Collect data using cameras.  
2. Select all `.mp4` files and copy them into a single source directory.  
3. Run the script to organize the files into episode folders.

## Usage

```bash
./ep_organizer.sh -s <source_directory> -d <destination_directory> -n <new_name> [-l number_length] [-i start_index] [-r]
```

### Arguments

| Flag | Description |
|------|-------------|
| `-s` | Source directory containing `.mp4` files. |
| `-d` | Destination directory for episode folders. |
| `-n` | New filename inside episode folders (no need to add file extension). |
| `-l` | (Optional) Digits to use for sorting filenames (default: alphabetical). |
| `-i` | (Optional) Start index for episode folders (default: `1`). |
| `-r` | (Optional) If present, allows replacing existing files. |

## Example

```bash
./ep_organizer.sh -s ./source -d ./destination -n external -l 2 -i 1 -r
```

### Result

```
Episodes/
├── episode_1/
│   ├── external.mp4  # (first sorted file)
├── episode_2/
│   ├── external.mp4  # (second sorted file)
└── ...
```

## Installation

```bash
git clone https://github.com/yyyx-not-found/episode-organizer.git
cd episode-organizer
chmod +x ep_organizer.sh
```

## License

This project is licensed under the MIT License.

## Contact

GitHub: [YourGitHubProfile](https://github.com/yyyx-not-found)  
Email: yixiany2@illinois.edu
