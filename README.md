# onedrive-downloader

## About

This repository contains scripts to download files from OneDrive links via the terminal.

Currently, there are two versions of the scripts: one uses `curl` and the other uses `wget` for HTTP requests. Both scripts utilize `grep`, `base64`, and `tr`.

These scripts retrieve a "badger" token and prepare the target file for download.

## Usage

Each script is self-contained. Choose the script that uses the tool available in your environment (`curl` or `wget`).

```bash
./curl_onedrive_url.sh <ONE_DRIVE_URL>
```

or

```
$ ./wget_onedrive_url.sh <ONE_DRIVE_URL>
```

where <ONE_DRIVE_URL> is a OneDrive URL in the format "https://1drv.ms/u/s!XXX".

## References

- [OneDrive Encoding sharing URLs](https://learn.microsoft.com/en-us/onedrive/developer/rest-api/api/shares_get?view=odsp-graph-online#encoding-sharing-urls)