# onedrive-downloader

## About

This repository contains scripts to download files from OneDrive links via the terminal.

Currently, there are two versions of the scripts: one uses `curl` and the other uses `wget` for HTTP requests. Both scripts utilize `grep`, `base64`, and `tr`.

These scripts retrieve a "badger" token and prepare the target file for download.

## Usage

Each script is self-contained. Choose the script that uses the tool available in your environment (`curl` or `wget`).

```
Usage:
  ./<curl|wget>_onedrive_url.sh [-d <OUT_DIR>] [-f <OUT_FILE>] <ONE_DRIVE_URL>

Options:
  -d <OUT_DIR>: specifies the output directory for the file(s) keeping the original filename (e.g., -d /home/user)
  -f <OUT_FILE>: sets the local filename (e.g., -f ~/Downloads/file.zip)

Args:
  <ONE_DRIVE_URL>: A OneDrive URL (e.g., https://1drv.ms/u/s!XXX)
```

### Examples

```bash
$ ./curl_onedrive_url.sh <ONE_DRIVE_URL>
```

or

```bash
$ ./wget_onedrive_url.sh <ONE_DRIVE_URL>
```

## References

- [OneDrive Encoding sharing URLs](https://learn.microsoft.com/en-us/onedrive/developer/rest-api/api/shares_get?view=odsp-graph-online#encoding-sharing-urls)