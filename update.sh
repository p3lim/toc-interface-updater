#!/bin/bash

if [[ -z "$WOWI_API_TOKEN" ]]; then
	echo "Missing WOWI_API_TOKEN"
	exit 1
fi

# dictates which Interface version will be used by default
BASE_VERSION="${1:-retail}"

# query WoWInterface API for interface versions
data="$(curl -sSLH"X-API-Token: $WOWI_API_TOKEN" "https://api.wowinterface.com/addons/compatible.json")"
if jq '.ERROR' <<< "$data" 2>/dev/null; then
	# error from the API
	echo "Error: $(jq -r '.ERROR' <<< "$data")"
	exit 1
elif [[ -z "$data" ]]; then
	# error from the query
	echo "Error: no data from WoWInterface API"
	exit 1
fi

# map interface versions
declare -A versions
versions[retail]="$(jq -r --arg v 'Retail' '.[] | select(.game == $v) | select(.default == true) | .interface' <<< "$data")"
versions[classic]="$(jq -r --arg v 'Classic' '.[] | select(.game == $v) | .interface' <<< "$data")"
versions[bcc]="$(jq -r --arg v 'TBC-Classic' '.[] | select(.game == $v) | .interface' <<< "$data")"

# ensure we have interface versions
if [[ -z "${versions[retail]}" ]]; then
	echo "Failed to get retail interface version from WoWInterface API"
	exit 1
fi
if [[ -z "${versions[classic]}" ]]; then
	echo "Failed to get classic interface version from WoWInterface API"
	exit 1
fi
if [[ -z "${versions[bcc]}" ]]; then
	echo "Failed to get tbc-classic interface version from WoWInterface API"
	exit 1
fi

# write to TOC files
while read -r file; do
	before="$(md5sum "$file")"

	# replace the interface version value based on the defined fallback game version
	sed -ri "s/^(## Interface:).*\$/\1 ${versions[$BASE_VERSION]}/" "$file"

	# replace game-specific interface version values used by the BigWigs/CurseForge packagers
	sed -ri "s/^(## Interface-Retail:).*\$/\1 ${versions[retail]}/" "$file"
	sed -ri "s/^(## Interface-Classic:).*\$/\1 ${versions[classic]}/" "$file"
	sed -ri "s/^(## Interface-BCC:).*\$/\1 ${versions[bcc]}/" "$file"

	if [[ "$(md5sum "$file")" != "$before" ]]; then
		echo "Updated $file"
	fi
done < <(find . -name '*.toc')
