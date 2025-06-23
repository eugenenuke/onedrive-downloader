# onedrive-downloader

## About

This repository contains a Bash script for downloading files and folders from OneDrive links directly via the terminal.

The script authenticates with the OneDrive API by retrieving a 'badger' token, which grants it access to shared files. It intelligently handles both individual file downloads and recursive folder downloads, preserving the original directory structure.

### Dependencies

The script requires either `curl` or `wget` (preferring `wget` if both are present) for making HTTP requests. Additionally, the following common Unix utilities are needed for data processing: `base64`, `grep`, `sed`, and `tr`.

## Usage

```
Usage:
  ./fetch_onedrive_url.sh [-d <OUT_DIR>] [-f <OUT_FILE>] <ONE_DRIVE_URL>

Options:
  -d <OUT_DIR>: Specifies the output directory for the downloaded file(s). If not provided, files will be saved in the current directory. When downloading a folder, the original directory structure will be preserved under this path (e.g., `-d /home/user/downloads`)
  -f <OUT_FILE>: Sets the local filename for a single file download (e.g., `-f ~/Downloads/my_document.zip`). This option is **ignored** if the provided OneDrive URL points to a folder.

Args:
  <ONE_DRIVE_URL>: The shared OneDrive URL (e.g., https://1drv.ms/u/s!AbCDeF_example)
```

### Behavior Notes

* **Progress Indicator:** A progress bar will be displayed during active file downloads to show transfer progress.
* **Folder Downloads:** If the `<ONE_DRIVE_URL>` points to a folder, the script will automatically download all its contents (files and nested subfolders recursively) into the specified output directory (`-d`). The `-f` option will be disregarded in this scenario as it's not applicable to folder downloads.
* **Error Handling:** The script is designed to exit with a non-zero status code and an informative error message if issues such as invalid URLs, network problems, or API failures occur during token retrieval or download.

### Examples

```bash
# Download a file to the current directory with its original filename
$ ./fetch_onedrive_url.sh https://1drv.ms/u/s!AbCDeF_your_file

# Download a file and save it as 'my_archive.zip' in the current directory
$ ./fetch_onedrive_url.sh -f my_archive.zip https://1drv.ms/u/s!AbCDeF_another_file

# Download a file to a specific directory, keeping its original filename
$ ./fetch_onedrive_url.sh -d /tmp/downloads https://1drv.ms/u/s!AbCDeF_my_document

# Download a file to a specific directory with a custom filename
$ ./fetch_onedrive_url.sh -d /tmp/downloads -f report.pdf https://1drv.ms/u/s!AbCDeF_yearly_report

# Download an entire folder, preserving its structure under /tmp/onedrive_content
$ ./fetch_onedrive_url.sh -d /tmp/onedrive_content https://1drv.ms/f/s!AbCDeF_my_folder
```

## References

* [OneDrive Encoding sharing URLs](https://learn.microsoft.com/en-us/onedrive/developer/rest-api/api/shares_get?view=odsp-graph-online#encoding-sharing-urls)
