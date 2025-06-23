#!/bin/bash
#
# OneDrive Downloader: A tool to download files from OneDrive links via the terminal.
#
# The script authenticates with the OneDrive API by retrieving a 'badger' token,
# which grants it access to shared files. It intelligently handles both
# individual file downloads and recursive folder downloads, preserving the
# original directory structure.
#
# Commands used:
#   - curl / wget
#   - base64
#   - grep
#   - sed
#   - tr

set -euo pipefail

# Uncomment to enforce usage of `curl` when `wget` is present in the system
# FORCE_CURL=true

# Initial defaults for curl
FETCH="curl"
SILENT_OPT="-s"
TO_FILE_OPT="-o"
TO_DIR_OPT="--create-dirs --output-dir"
HEADER_OPT="-H"
POST_DATA_OPT="-d"
PROGRESS_OPT="--progress-bar --progress-meter"
CONTENT_DISPOSITION_OPT="-OJ"
FETCH_CMD="$FETCH $PROGRESS_OPT"

if [[ "${FORCE_CURL:-false}" != "true" ]] && type wget > /dev/null ; then
  # Use `wget` if present
  FETCH="wget"
  SILENT_OPT="-q"
  TO_FILE_OPT="-O"
  TO_DIR_OPT="-P"
  HEADER_OPT="--header"
  POST_DATA_OPT="--post-data"
  PROGRESS_OPT="--show-progress"
  CONTENT_DISPOSITION_OPT="--content-disposition"
  FETCH_CMD="$FETCH $SILENT_OPT $PROGRESS_OPT"
fi

TO_STDOUT_OPT="${TO_FILE_OPT}-"

ONE_DRIVE_API_ENDPOINT="https://my.microsoftpersonalcontent.com/_api/v2.0"

download_file() {
  local download_url="$1"
  local dir="$2"
  local filename="$3"

  if [[ -z "$filename" ]]; then
    $FETCH_CMD "$download_url" \
      $CONTENT_DISPOSITION_OPT \
      $TO_DIR_OPT "$dir"

  else
    $FETCH_CMD "$download_url" \
      $TO_FILE_OPT "$filename" \
      $TO_DIR_OPT "$dir"
  fi
}

download_folder() {
  local folder_url="$1"
  local token="$2"
  local dir="$3"

  local children=$($FETCH_CMD $SILENT_OPT $TO_STDOUT_OPT \
    $HEADER_OPT "Authorization: Badger $token"\
    $folder_url)

  while read -r url_or_id name
  do
    if [[ $url_or_id == http* ]]
    then
      download_file "$url_or_id" "$dir" ""
    else
      echo Entering "$dir/$name" ...
      # Making directories explicitly to handle a case with empty dirs
      mkdir -p "$dir/$name"
      download_folder "$(get_folder_url $url_or_id)" "$token" "$dir/$name"
    fi
  done < <(extract_children "$children")

  local next_link=$(extract_next_link "$children")
  if [[ -n "$next_link" ]]; then
    download_folder "$next_link" "$token" "$dir"
  fi
}

get_badger_token() {
  local json=$($FETCH_CMD $SILENT_OPT $TO_STDOUT_OPT \
    $HEADER_OPT "Content-Type: application/json" \
    $POST_DATA_OPT '{"appId":"5cbed6ac-a083-4e14-b191-b4ba07653de2"}' \
    https://api-badgerp.svc.ms/v1.0/token)

  if [[ -z "$json" ]]; then
    echo "Error: Failed to retrieve Badger token." >&2
    exit 1
  fi

  local token=$(extract_badger_token "$json")

  if [[ -n "$token" ]]; then
      echo "$token"
  else
      echo "Error: Failed to parse Badger token." >&2
      exit 1
  fi
}

get_folder_url() {
  local folder_id="$1"
  local drive_id="${folder_id%%!*}"
  
  echo "$ONE_DRIVE_API_ENDPOINT/drives/$drive_id/items/$folder_id?select=children&expand=children(select=name,@content.downloadUrl,id)"
}

get_root_item() {
  local onedrive_encoded_url="$1"
  local token="$2"

  $FETCH_CMD $SILENT_OPT $TO_STDOUT_OPT \
    $HEADER_OPT "Accept: application/json" \
    $HEADER_OPT "Prefer: autoredeem" \
    $HEADER_OPT "Authorization: Badger $token" \
	  $POST_DATA_OPT '' \
    "$ONE_DRIVE_API_ENDPOINT/shares/u!$onedrive_encoded_url/driveitem?select=@content.downloadUrl,id,name"
}

encode_url() {
  # see https://learn.microsoft.com/en-us/onedrive/developer/rest-api/api/shares_get?view=odsp-graph-online#encoding-sharing-urls
  local url="$1"
  echo -n "$url" | base64 -w0 | tr -d '=' | tr '/+' '_-'
}

extract_value() {
  local key="$1"
  local json="$2"

  # echo $json | jq -r 'if ."'$key'" then ."'$key'" else "" end'
  echo "$json" | grep -oP '"'$key'":"\K[^"]+' || true
}

extract_badger_token() {
  extract_value "token" "$1"
}

extract_download_link() {
  extract_value "@content.downloadUrl" "$1"
}

extract_folder_id() {
  extract_id "$1"
}

extract_id() {
  extract_value "id" "$1"
}

extract_name() {
  extract_value "name" "$1"
}

extract_next_link() {
  extract_value "@odata.nextLink" "$1"
}

extract_children() {
  local children="$1"
  local key=""
  local value=""
  local id=""
  local url=""
  local name=""

  # echo $children | jq -r '.children[] | (if ."@content.downloadUrl" then ."@content.downloadUrl" else .id end) + " " + .name'

  # extract the `children` content
  children=$(echo "$children" | grep -oP '(?<="children":)\[.*?\]')

  if [[ "$children" != "[]" ]]; then
    while read -r child
      do
        id=$(extract_id $child)
        name=$(extract_name $child)
        url=$(extract_download_link $child)

        if [[ -n "$url" ]]; then
          echo "$url" "$name"
        else
          echo "$id" "$name"
        fi

      # split children, each on separate line
      done < <(echo "$children" | sed -E 's/\},\{/\}\n{/g; s/^\[//; s/\]$//')
  fi
}

usage() {
  cat << EOF
Usage:
  $0 [-d <OUT_DIR>] [-f <OUT_FILE>] <ONE_DRIVE_URL>

Options:
  -d <OUT_DIR>: Specifies the output directory for the downloaded file(s).
                If not provided, files will be saved in the current directory.
                When downloading a folder, the original directory structure
                will be preserved under this path
                (e.g., `-d /home/user/downloads`)
  -f <OUT_FILE>: Sets the local filename for a single file download
                (e.g., `-f ~/Downloads/my_document.zip`). This option is
                **ignored** if the provided OneDrive URL points to a folder.

Args:
  <ONE_DRIVE_URL>: The shared OneDrive URL (e.g., https://1drv.ms/u/s!AbCDeF_example)

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
token=$(get_badger_token)
root_item=$(get_root_item "$onedrive_encoded_url" "$token")

download_url=$(extract_download_link $root_item)
if [[ -n "$download_url" ]]; then
  download_file "$download_url" "$out_dir" "$out_file" 
else
  echo "The url leads to a folder, downloading the folder's content. -f flag will be ignored"
  folder_id=$(extract_folder_id $root_item)
  download_folder "$(get_folder_url $folder_id)" "$token" "$out_dir"
fi
