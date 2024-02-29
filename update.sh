#!/bin/bash

FLAVOR="${1:-retail}"
FUTURE="$2"
if [[ ! "${FUTURE,,}" =~ ^(y|yes|true|1)$ ]]; then
	FUTURE=''
fi

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

declare -A versions
function product_version {
	local product="$1"

	# check if version is cached
	if [ "${versions[$product]+x}" ]; then
		# return cached version
		echo "${versions[$product]}"
	else
		# grab version from CDN, get the version field
		version="$(nc 'us.version.battle.net' 1119 <<< "v1/products/$product/versions" | awk -F'|' '/^us/{print $6}')"

		# strip away build number
		version="${version%.*}"

		# classic_era needs to be handled differently
		if [[ "$version" == 1.* ]]; then
			# strip away major-minor delimiter
			version="${version/./}"
		fi

		# replace delimiters with 0, creating the interface version
		version="${version//./0}"

		# cache version
		versions[$product]="$version"

		echo "$version"
	fi
}

# define function to update interface version in TOC files
function replace {
	local file="$1"
	local product="${2:-$PRODUCT}"
	local multi="${3:-false}"

	# generate a hash of the file before we potentially modify it
	local checksum
	checksum="$(md5sum "$file")"

	local future
	local version
	version="$(product_version "$product")"

	# if we're checking beta/ptr
	if [ "x$FUTURE" != 'x' ]; then
		# flavor ref: https://wago.tools
		if [[ "$product" == 'wow' ]]; then
			future="$(product_version 'wow_beta')"
			if [[ "$future" -gt "$version" ]]; then
				version="$future"
			fi

			future="$(product_version 'wowt')" # PTR 1
			if [[ "$future" -gt "$version" ]]; then
				version="$future"
			fi

			future="$(product_version 'wowxptr')" # PTR 2
			if [[ "$future" -gt "$version" ]]; then
				version="$future"
			fi
		elif [[ "$product" == 'wow_classic_era' ]]; then
			future="$(product_version 'wow_classic_era_ptr')"
			if [[ "$future" -gt "$version" ]]; then
				version="$future"
			fi
		elif [[ "$product" == 'wow_classic' ]]; then
			future="$(product_version 'wow_classic_beta')"
			if [[ "$future" -gt "$version" ]]; then
				version="$future"
			fi

			future="$(product_version 'wow_classic_ptr')"
			if [[ "$future" -gt "$version" ]]; then
				version="$future"
			fi
		fi
	fi

	if [ "$multi" = 'true' ]; then
		# replace product suffix interface version in the file, supported by BigWigs' packager
		if [ "$product" = 'wow_classic_era' ]; then
			sed -ri "s/^(## Interface-Vanilla:).*\$/\1 ${version}/" "$file"
			sed -ri "s/^(## Interface-Classic:).*\$/\1 ${version}/" "$file" # legacy suffix, remove later
		elif [ "$product" = 'wow_classic' ]; then
			sed -ri "s/^(## Interface-Wrath:).*\$/\1 ${version}/" "$file"
			sed -ri "s/^(## Interface-WOTLKC:).*\$/\1 ${version}/" "$file" # legacy suffix, remove later
		fi
	else
		# replace the interface version value in the file
		sed -ri "s/^(## Interface:).*\$/\1 ${version}/" "$file"
	fi

	# output file status
	if [[ "$(md5sum "$file")" != "$checksum" ]]; then
		echo "Updated $file ($product)"
	fi
}

# update TOC files
while read -r file; do
	if ! [[ "$file" =~ [_-](Mainline|Classic|Vanilla|Wrath|WOTLKC).toc$ ]]; then
		replace "$file"
		replace "$file" 'wow_classic_era' 'true'
		replace "$file" 'wow_classic' 'true'
	elif [[ "$file" =~ [_-]Mainline.toc$ ]]; then
		replace "$file" 'wow'
	elif [[ "$file" =~ [_-](Classic|Vanilla).toc$ ]]; then
		replace "$file" 'wow_classic_era'
	elif [[ "$file" =~ [_-](Wrath|WOTLKC).toc$ ]]; then
		replace "$file" 'wow_classic'
	fi
done < <(find -- *.toc)
