#!/bin/bash

set -o errexit -o pipefail

function usage {
	cat << EOF
Options:
  --beta, -b    Include beta versions
  --ptr, -p     Include test versions
  --flavor, -f  Fallback game flavor (retail/classic/vanilla)
  --help, -h    Show this help text
EOF
}

BETA=false
TEST=false
DEFAULT='wow'

while true; do
	case "$1" in
		--help|-h)
			usage
			exit 0
			;;
		--flavor|-f)
			if [ -n "$2" ]; then
				case "$2" in
					retail|mainline)
						DEFAULT='wow'
						;;
					classic|cata)
						DEFAULT='wow_classic'
						;;
					classic_era|vanilla)
						DEFAULT='wow_classic_era'
						;;
					*)
						echo "Invalid flavor '$2', must be one of retail/mainline, classic/cata, or classic_era/vanilla."
						exit 1
						;;
				esac

				shift 2
			else
				echo 'Missing value'
				exit 1
			fi
			;;
		--beta|-b)
			BETA=true
			shift
			;;
		--ptr|-p)
			TEST=true
			shift
			;;
		--)
			shift
			break
			;;
		*)
			break
			;;
	esac
done

declare -A version_cache
function product_version {
	local product="$1"

	if [ "${version_cache[$product]+x}" ]; then
		# version is cached
		echo "${version_cache[$product]}"
	else
		# grab version from CDN, get the version field
		local version
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
		version_cache[$product]="$version"

		echo "$version"
	fi
}

function replace {
	local file="$1"
	local product="$2"
	local multi="${3:-false}"

	echo "Checking $file ($product)"

	# generate a hash of the file before we potentially modify it
	local checksum
	checksum="$(md5sum "$file")"

	# get base version
	local versions
	versions=("$(product_version "$product")")

	# iterate through beta versions and append them to the versions array
	if $BETA; then
		local products=()
		if [[ "$product" == 'wow' ]]; then
			products+=('wow_beta')
		elif [[ "$product" == 'wow_classic' ]]; then
			products+=('wow_classic_beta')
		fi

		for p in "${products[@]}"; do
			local version
			version="$(product_version "$p")"

			if ((version > versions[0])); then
				versions+=("$version")
			fi
		done
	fi

	# iterate through test versions and append them to the versions array
	if $TEST; then
		local products=()
		if [[ "$product" == 'wow' ]]; then
			products+=('wowt') # PTR 1
			products+=('wowxptr') # PTR 2
		elif [[ "$product" == 'wow_classic' ]]; then
			products+=('wow_classic_ptr')
		elif [[ "$product" == 'wow_classic_era' ]]; then
			products+=('wow_classic_era_ptr')
		fi

		for p in "${products[@]}"; do
			local version
			version="$(product_version "$p")"

			if ((version > versions[0])); then
				versions+=("$version")
			fi
		done
	fi

	# format multiple interface versions
	local interface
	interface="$(printf ", %s" "${versions[@]}")"
	interface="${interface:2}"

	# update version fields in-place
	if [ "$multi" = 'true' ]; then
		if [ "$product" = 'wow_classic' ]; then
			sed -ri "s/^(## Interface-Cata:).*\$/\1 ${interface}/" "$file"
		elif [ "$product" = 'wow_classic_era' ]; then
			sed -ri "s/^(## Interface-Vanilla:).*\$/\1 ${interface}/" "$file"
		fi
	else
		sed -ri "s/^(## Interface:).*\$/\1 ${interface}/" "$file"
	fi

	# output status
	if [[ "$(md5sum "$file")" != "$checksum" ]]; then
		echo "Updated $file ($product)"
	else
		echo "No changes to $file ($product)"
	fi
}

while read -r file; do
	if ! [[ "$file" =~ [_-](Mainline|Classic|Vanilla|Cata).toc$ ]]; then
		# assume multi-flavor
		replace "$file" "$DEFAULT"
		replace "$file" 'wow_classic' 'true'
		replace "$file" 'wow_classic_era' 'true'
	elif [[ "$file" =~ [_-](Mainline).toc$ ]]; then
		replace "$file" 'wow'
	elif [[ "$file" =~ [_-](Classic|Cata).toc$ ]]; then
		replace "$file" 'wow_classic'
	elif [[ "$file" =~ [_-](Vanilla).toc$ ]]; then
		replace "$file" 'wow_classic_era'
	fi
done < <(find . -type f -iname '*.toc' | sed 's/^.\///')
