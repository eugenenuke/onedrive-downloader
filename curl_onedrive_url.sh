#!/bin/bash
#
# OneDrive Downloader: A tool to download files from OneDrive links via the terminal.
#
# This script retrieves a "badger" token and prepares the target file for download.
#
# Commands used:
#   - curl
#   - grep
#   - base64
#   - tr

set -euo pipefail

usage() {
  cat << EOF
Usage:
  $0 [-d <OUT_DIR>] [-f <OUT_FILE>] <ONE_DRIVE_URL>

Options:
  -d <OUT_DIR>: specifies the output directory for the file(s) keeping the original filename (e.g., -d /home/user)
  -f <OUT_FILE>: sets the local filename (e.g., -f ~/Downloads/file.zip)

Args:
  <ONE_DRIVE_URL>: A OneDrive URL (e.g., https://1drv.ms/u/s!XXX)
EOF
}

validate_url() {
  local url="$1"
  if [[ "$url" =~ ^https://1drv\.ms/.+$ ]]; then
    return 0
  else
    return 1
  fi
}

encode_url() {
  # see https://learn.microsoft.com/en-us/onedrive/developer/rest-api/api/shares_get?view=odsp-graph-online#encoding-sharing-urls
  local url="$1"
  echo -n "$url" | base64 -w0 | tr -d '=' | tr '/+' '_-'
}

get_badger_token() {
  local token=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"appId":"5cbed6ac-a083-4e14-b191-b4ba07653de2"}' \
    https://api-badgerp.svc.ms/v1.0/token)

  if [[ -n "$token" ]]; then
      token=$(echo "$token" | grep -oP '"token":"\K[^"]+')
      if [[ -n "$token" ]]; then
          echo "$token"
      else
          echo "Error: Failed to parse Badger token." >&2
          exit 1
      fi
  else
    echo "Error: Failed to retrieve Badger token." >&2
    exit 1
  fi
}

get_drive_id() {
  # Without this call the actual downloading call will be rejected as Unauthorized
  local onedrive_encoded_url="$1"
  local token="$2"

  local drive_id=$(curl -s \
    -H "Accept: application/json" \
    -H "Prefer: autoredeem" \
    -H "Authorization: Badger $token" \
    "https://my.microsoftpersonalcontent.com/_api/v2.0/shares/u!$onedrive_encoded_url/driveitem?%24select=id%2CparentReference")

  if [[ -n "$drive_id" ]]; then
      drive_id=$(echo "$drive_id" | grep -oP '"driveId":"\K[^"]+' | tr '[:upper:]' '[:lower:]')
      if [[ -n "$drive_id" ]]; then
          echo "$drive_id"
      else
          echo "Error: Failed to parse drive ID." >&2
          exit 1
      fi
  else
    echo "Error: Failed to retrieve drive ID." >&2
    exit 1
  fi
}

get_url_type() {
  local onedrive_encoded_url="$1"
  local token="$2"

  curl -s "https://api.onedrive.com/v1.0/shares/u!$onedrive_encoded_url/driveItem?\$expand=children" \
    -H "Authorization: Badger $token" | grep -q '"folder":' && echo "folder" || echo "file"
}

download_file() {
  local onedrive_encoded_url="$1"
  local token="$2"
  local dir="$3"
  local filename="$4"

  local target_url=$(curl -s -w %{redirect_url} -o /dev/null "https://api.onedrive.com/v1.0/shares/u!$onedrive_encoded_url/root/content" \
    -H "Authorization: Badger $token")

  if [[ -z "$filename" ]]; then
      filename=$(curl -sI "$target_url" |
        grep -i "Content-Disposition" |
        sed 's/.*filename="//; s/".*//')
  fi

  curl --progress-bar -o "$dir/$filename" "$target_url"
}

download_folder() {
  local onedrive_encoded_url="$1"
  local token="$2"
  local dir="$3"

  while IFS= read -r url
  do
    filename=$(curl -sI "$url" | grep -i "Content-Disposition" |
        sed 's/.*filename="//; s/".*//')
    curl --progress-bar -o "$dir/$filename" "$url"
  done < <(curl -s "https://api.onedrive.com/v1.0/shares/u!$onedrive_encoded_url/driveItem?\$expand=children" \
    -H "Authorization: Badger $token" | grep -oP '"@content.downloadUrl":"\K[^"]+')
}

out_file=""
out_dir="."

while getopts "hf:d:" opt; do
  case ${opt} in
    f)
      out_file="${OPTARG}"
      ;;
    d)
      out_dir="${OPTARG}"
      ;;
    h)
      usage
      exit 1
      ;;
    :)
      echo "Option -${OPTARG} requires an argument."
      exit 1
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

onedrive_url="$1"

if ! validate_url "$onedrive_url"; then
  echo "Error: Invalid OneDrive URL format." >&2
  usage
  exit 1
fi

onedrive_encoded_url=$(encode_url "$onedrive_url")
badger_token=$(get_badger_token)
drive_id=$(get_drive_id "$onedrive_encoded_url" "$badger_token")
url_type=$(get_url_type "$onedrive_encoded_url" "$badger_token")

if [[ "$url_type" = "file" ]]
then
  download_file "$onedrive_encoded_url" "$badger_token" "$out_dir" "$out_file" 
else
  echo "The url leads to a folder, downloading the folder's content. -f flag will be ignored"
  download_folder "$onedrive_encoded_url" "$badger_token" "$out_dir"
fi