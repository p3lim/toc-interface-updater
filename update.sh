#!/bin/bash

# let the user decide which interface version to fall back on, used for
# the BigWigs/CurseForge packager method of declaring the interface version
BASE_VERSION="${1:-mainline}"
case "$BASE_VERSION" in
	retail)
		# backwards compatibility
		BASE_VERSION='mainline'
		;;
	mainline|classic|bcc|wrath)
		# valid options
		;;
	vanilla)
		# for convenience
		BASE_VERSION='classic'
		;;
	tbc)
		# for convenience
		BASE_VERSION='bcc'
		;;
	wotlkc)
		# for convenience
		BASE_VERSION='wrath'
		;;
	*)
		# invalid options
		echo "Invalid base version '$BASE_VERSION', must be one of mainline/classic/vanilla/bcc/tbc/wrath/wotlkc."
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

# map interface versions
declare -A versions
versions[mainline]="$(jq -r --arg v 'Retail' '[.[] | select(.game == $v)][0] | .interface' <<< "$data")"
versions[classic]="$(jq -r --arg v 'Classic' '[.[] | select(.game == $v)][0] | .interface' <<< "$data")"
versions[bcc]="$(jq -r --arg v 'TBC-Classic' '[.[] | select(.game == $v)][0] | .interface' <<< "$data")"
versions[wrath]="$(jq -r --arg v 'WOTLK-Classic' '[.[] | select(.game == $v)][0] | .interface' <<< "$data")"

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
if [[ -z "${versions[wrath]}" ]]; then
	echo "Failed to get wotlk-classic interface version from WoWInterface API"
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
		sed -ri "s/^(## Interface:).*\$/\1 ${versions[$BASE_VERSION]}/" "$file"

		# replace game-specific interface version values supported by the BigWigs packager
		sed -ri "s/^(## Interface-Retail:).*\$/\1 ${versions[mainline]}/" "$file"
		sed -ri "s/^(## Interface-Classic:).*\$/\1 ${versions[classic]}/" "$file"
		sed -ri "s/^(## Interface-BCC:).*\$/\1 ${versions[bcc]}/" "$file"
		sed -ri "s/^(## Interface-Wrath:).*\$/\1 ${versions[wrath]}/" "$file"
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
	if ! [[ "$file" =~ [_-](Mainline|Classic|Vanilla|BCC|TBC|Wrath|WOTLKC).toc$ ]]; then
		replace "$file"
	elif [[ "$file" =~ [_-]Mainline.toc$ ]]; then
		replace "$file" 'mainline'
	elif [[ "$file" =~ [_-](Classic|Vanilla).toc$ ]]; then
		replace "$file" 'classic'
	elif [[ "$file" =~ [_-](BCC|TBC).toc$ ]]; then
		replace "$file" 'bcc'
	elif [[ "$file" =~ [_-](Wrath|WOTLKC).toc$ ]]; then
		replace "$file" 'wrath'
	fi
done < <(find -- *.toc)
