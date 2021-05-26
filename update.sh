#!/bin/bash

if [[ -z "$WOWI_API_TOKEN" ]]; then
	echo "Missing WOWI_API_TOKEN"
	exit 1
fi

# let the user decide which interface version to fall back on, used for
# the BigWigs/CurseForge packager method of declaring the interface version
BASE_VERSION="${1:-mainline}"
case "$BASE_VERSION" in
	retail)
		# backwards compatibility
		BASE_VERSION='mainline'
		;;
	mainline|classic|bcc)
		# valid options
		;;
	*)
		# invalid options
		echo "Invalid base version '$BASE_VERSION', must be one of mainline/classic/bcc."
		exit 1
		;;
esac

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
versions[mainline]="$(jq -r --arg v 'Retail' '.[] | select(.game == $v) | select(.default == true) | .interface' <<< "$data")"
versions[classic]="$(jq -r --arg v 'Classic' '.[] | select(.game == $v) | .interface' <<< "$data")"
versions[bcc]="$(jq -r --arg v 'TBC-Classic' '.[] | select(.game == $v) | .interface' <<< "$data")"

# ensure we have interface versions
if [[ -z "${versions[mainline]}" ]]; then
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

# declare method to update interface version in TOC files
function replace {
	local file="$1"
	local version="$2"

	# generate a hash of the file before we potentially modify it
	local checksum="$(md5sum "$file")"

	if [[ -z "$version" ]]; then
		echo "--- UPDATING $file"
		# replace the interface version value based on the defined fallback game version
		sed -ri "s/^(## Interface:).*\$/\1 ${versions[$BASE_VERSION]}/" "$file"

		# replace game-specific interface version values used by the BigWigs/CurseForge packagers
		sed -ri "s/^(## Interface-Retail:).*\$/\1 ${versions[mainline]}/" "$file"
		sed -ri "s/^(## Interface-Classic:).*\$/\1 ${versions[classic]}/" "$file"
		sed -ri "s/^(## Interface-BCC:).*\$/\1 ${versions[bcc]}/" "$file"
	else
		echo "--- FIXING $file"
		# replace the interface version value
		sed -ri "s/^(## Interface:).*\$/\1 ${versions[$version]}/" "$file"
	fi

	# output file status
	if [[ "$(md5sum "$file")" != "$checksum" ]]; then
		echo "Updated $file"
	fi
}

# update generic TOC files
while read -r file; do
	replace "$file"
done < <(find . -name '*.toc' ! -name '*-Mainline.toc' ! -name '*-Classic.toc' ! -name '*-BCC.toc')

# update version-specific TOC files
while read -r file; do
	replace "$file" 'mainline'
done < <(find . -name '*-Mainline.toc')

while read -r file; do
	replace "$file" 'classic'
done < <(find . -name '*-Classic.toc')

while read -r file; do
	replace "$file" 'bcc'
done < <(find . -name '*-BCC.toc')
