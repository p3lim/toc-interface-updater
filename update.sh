#!/bin/bash

if [[ -z "$WOWI_API_TOKEN" ]]; then
	echo "Missing WOWI_API_TOKEN"
	exit 1
fi

# dictates which Interface version will be used by default
BASE_VERSION="${1:-retail}"

# query WoWInterface for Interface version (e.g. 90005)
data="$(curl -sSLH"X-API-Token: $WOWI_API_TOKEN" "https://api.wowinterface.com/addons/compatible.json")"
if jq '.ERROR' <<< "$data" 2>/dev/null; then
	# if this doesn't fail then we have an error
	echo "Error: $(jq -r '.ERROR' <<< "$data")"
	exit 1
elif [[ -z "$data" ]]; then
	echo "Error: no data from WoWInterface API"
	exit 1
fi

# map interface version to variables based on game version
retailInterfaceVersion="$(jq -r --arg v 'Retail' '.[] | select(.game == $v) | .interface' <<< "$data")"
classicInterfaceVersion="$(jq -r --arg v 'Classic' '.[] | select(.game == $v) | .interface' <<< "$data")"
bccInterfaceVersion="$(jq -r --arg v 'TBC-Classic' '.[] | select(.game == $v) | .interface' <<< "$data")"

if [[ -z "$retailInterfaceVersion" ]] || [[ -z "$classicInterfaceVersion" ]]; then
	echo "Failed to get interface version from WoWInterface"
	exit 1
fi

# write to TOC files
while read -r file; do
	before="$(md5sum "$file")"

	case "${BASE_VERSION,,}" in
		retail) sed -ri 's/^(## Interface: ).*$/\1'"$retailInterfaceVersion"'/' "$file" ;;
		classic) sed -ri 's/^(## Interface: ).*$/\1'"$classicInterfaceVersion"'/' "$file" ;;
		bcc) sed -ri 's/^(## Interface: ).*$/\1'"$bccInterfaceVersion"'/' "$file" ;;
	esac

	sed -ri 's/^(## Interface-Retail: ).*$/\1'"$retailInterfaceVersion"'/' "$file"
	sed -ri 's/^(## Interface-Classic: ).*$/\1'"$classicInterfaceVersion"'/' "$file"
	sed -ri 's/^(## Interface-BCC: ).*$/\1'"$bccInterfaceVersion"'/' "$file"

	if [[ "$(md5sum "$file")" != "$before" ]]; then
		echo "Updated $file"
	fi
done < <(find . -name '*.toc')
