#!/bin/bash
#
# OneDrive Downloader: A tool to download files from OneDrive links via the terminal.
#
# This script retrieves a "badger" token and prepares the target file for download.
#
# Commands used:
#   - wget
#   - grep
#   - base64
#   - tr

set -euo pipefail

usage() {
  cat << EOF
Usage:
  $0 <ONE_DRIVE_URL>

Args:
  <ONE_DRIVE_URL>: A OneDrive URL (e.g., https://1drv.ms/u/s!XXX)
EOF
}

validate_url() {
  local url="$1"
  if [[ "$url" =~ ^https://1drv\.ms/u/s!.+$ ]]; then
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
  local token=$(wget -qO- \
    --header "Content-Type: application/json" \
    --post-data '{"appId":"5cbed6ac-a083-4e14-b191-b4ba07653de2"}' \
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

  local drive_id=$(wget -qO - \
    --header "Accept: application/json" \
    --header "Prefer: autoredeem" \
    --header "Authorization: Badger $token" \
	  --post-data '' \
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

download_file() {
  local onedrive_encoded_url="$1"
  local token="$2"

  wget -q "https://api.onedrive.com/v1.0/shares/u!$onedrive_encoded_url/root/content" \
	  --header "Authorization: Badger $token" \
    --show-progress \
	  --content-disposition
}

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

download_file "$onedrive_encoded_url" "$badger_token"