#!/bin/bash

# let the user decide which interface version to fall back on
FLAVOR="${1:-retail}"
case "$FLAVOR" in
	retail|classic_era|classic)
		# valid options
		;;
	mainline)
		# backwards compatibility
		FLAVOR='retail'
		;;
	vanilla)
		# for convenience
		FLAVOR='classic_era'
		;;
	wrath|wotlkc)
		# for convenience
		FLAVOR='classic'
		;;
	*)
		echo "Invalid flavor '$FLAVOR', must be one of retail/mainline, classic_era/vanilla, classic/wrath/wotlkc."
		exit 1
		;;
esac

# query WoWInterface API for interface versions
data="$(curl -sSL "https://api.wowinterface.com/addons/compatible.json")"
if jq '.ERROR' <<< "$data" 2>/dev/null; then
	# error from the API
	echo "Error from WoWInterface API: $(jq -r '.ERROR' <<< "$data")"
	exit 1
elif [[ -z "$data" ]]; then
	# error from the query
	echo "Failed to get data from WoWInterface API"
	exit 1
fi

# lowercase entire dataset
data="$(tr A-Z a-z <<< "$data")"

# map interface versions
declare -A versions
versions[retail]="$(jq -r --arg v 'retail' '.[] | select(.game == $v) | .interface' <<< "$data" | sort -n -r | head -n1)"
versions[classic_era]="$(jq -r --arg v 'classic' '.[] | select(.game == $v) | .interface' <<< "$data" | sort -n -r | head -n1)"
versions[classic]="$(jq -r --arg v 'wotlk-classic' '.[] | select(.game == $v) | .interface' <<< "$data" | sort -n -r | head -n1)"

# ensure we have interface versions
if [[ -z "${versions[retail]}" ]]; then
	echo "Failed to get retail interface version from WoWInterface API"
	exit 1
fi
if [[ -z "${versions[classic_era]}" ]]; then
	echo "Failed to get classic era interface version from WoWInterface API"
	exit 1
fi
if [[ -z "${versions[classic]}" ]]; then
	echo "Failed to get classic interface version from WoWInterface API"
	exit 1
fi

# declare method to update interface version in TOC files
function replace {
	local file="$1"
	local version="$2"

	# generate a hash of the file before we potentially modify it
	local checksum
	checksum="$(md5sum "$file")"

	if [[ -z "$version" ]]; then
		# replace the interface version value based on the defined fallback game version
		sed -ri "s/^(## Interface:).*\$/\1 ${versions[$FLAVOR]}/" "$file"
	else
		# replace the interface version value
		sed -ri "s/^(## Interface:).*\$/\1 ${versions[$version]}/" "$file"
	fi

	# output file status
	if [[ "$(md5sum "$file")" != "$checksum" ]]; then
		echo "Updated $file"
	fi
}

# update TOC files
while read -r file; do
	if ! [[ "$file" =~ [_-](Mainline|Classic|Vanilla|Wrath|WOTLKC).toc$ ]]; then
		replace "$file"
	elif [[ "$file" =~ [_-]Mainline.toc$ ]]; then
		replace "$file" 'retail'
	elif [[ "$file" =~ [_-](Classic|Vanilla).toc$ ]]; then
		replace "$file" 'classic_era'
	elif [[ "$file" =~ [_-](Wrath|WOTLKC).toc$ ]]; then
		replace "$file" 'classic'
	fi
done < <(find -- *.toc)
