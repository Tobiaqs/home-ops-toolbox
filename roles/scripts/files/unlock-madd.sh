#!/usr/bin/env bash
set -euo pipefail

madd_get() {
    local key="$1"
    local host="${2:-maddkeys.com}"
    local port="${3:-2222}"

    ssh -T -o IdentitiesOnly=yes -p "$port" -i "$key" "mk@$host" \
        | base64 -d \
        | openssl pkeyutl -decrypt \
            -inkey "$key" \
            -pkeyopt rsa_padding_mode:oaep \
            -pkeyopt rsa_oaep_md:sha256 \
            -in /dev/stdin
    echo
}

DEVICE_UUID="$1"
DEVICE="/dev/disk/by-uuid/$DEVICE_UUID"
MAPPER_NAME="luks-$DEVICE_UUID"
KEY_FILE="$2"

RETRY_DELAY=30

# Already unlocked?
if cryptsetup status "$MAPPER_NAME" &>/dev/null; then
  exit 0
fi

while true; do
  echo "Attempting to fetch LUKS key..."

  KEY=$(madd_get "$KEY_FILE" 2>/dev/null)

  if [[ "$KEY" != "" ]]; then
    echo -n "$KEY" | cryptsetup luksOpen "$DEVICE" "$MAPPER_NAME" --key-file=-
    echo "LUKS device unlocked"
    exit 0
  fi

  echo "Key fetch failed, retrying in ${RETRY_DELAY}s..."
  sleep "$RETRY_DELAY"

  exit 1
done
