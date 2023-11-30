#!/bin/bash

FLAVOR="${1:-retail}"
PRODUCT=
case "$FLAVOR" in
	retail|mainline)
		PRODUCT='wow'
		;;
	classic_era|vanilla)
		PRODUCT='wow_classic_era'
		;;
	classic|wrath|wotlk)
		PRODUCT='wow_classic'
		;;
	*)
		echo "Invalid flavor '$FLAVOR', must be one of retail/mainline, classic_era/vanilla, classic/wrath/wotlkc."
		exit 1
		;;
esac

# define function to update interface version in TOC files
function replace {
	local file="$1"
	local product="${2:-$PRODUCT}"

	# generate a hash of the file before we potentially modify it
	local checksum
	checksum="$(md5sum "$file")"

	# grab version from CDN, get the version field
	version="$(nc 'us.version.battle.net' 1119 <<< "v1/products/$product/versions" | awk -F'|' '/^us/{print $6}')"

	# strip away build number
	version="${version%.*}"

	# classic_era needs to be handled differently
	if [[ "$version" == 1.* ]]; then
		# strip away major-minor delimiter
		version="$(sed 's/\.//' <<< "$version")"
	fi

	# replace delimiters with 0, creating the interface version
	version="$(tr . 0 <<< "$version")"

	# replace the interface version value in the file
	sed -ri "s/^(## Interface:).*\$/\1 ${version}/" "$file"

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
		replace "$file" 'wow'
	elif [[ "$file" =~ [_-](Classic|Vanilla).toc$ ]]; then
		replace "$file" 'wow_classic_era'
	elif [[ "$file" =~ [_-](Wrath|WOTLKC).toc$ ]]; then
		replace "$file" 'wow_classic'
	fi
done < <(find -- *.toc)
