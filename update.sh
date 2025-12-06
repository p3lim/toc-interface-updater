#!/bin/bash

set -TEeuo pipefail

function usage {
	cat << EOF
$0 [OPTIONS]

Options:
  --beta, -b    Include beta versions
  --ptr, -p     Include test versions
  --flavor, -f  Game flavor(s), can be specified multiple times
  --depth, -d   Set max recursion into subdirectories
  --help, -h    Show this help text
EOF
}

BETA=false
TEST=false
DEPTH='99'
FLAVORS=()

args="$(getopt -n "$0" -l 'help,flavor:,beta,ptr,depth:' -o 'hf:bpd:' -- "$@")"
eval set -- "$args"

while [ $# -ge 1 ]; do
	case "$1" in
		--help|-h)
			usage
			exit 0
			;;
		--flavor|-f)
			if [[ "${2,,}" =~ (retail|mainline) ]]; then
				FLAVORS+=('wow')
			elif [[ "${2,,}" =~ (classic_era|vanilla) ]]; then
				FLAVORS+=('wow_classic_era')
			elif [[ "${2,,}" =~ (classic|mists) ]]; then
				FLAVORS+=('wow_classic')
			elif [[ "${2,,}" =~ (titan|wrath) ]]; then
				FLAVORS+=('wow_classic_titan')
			else
				echo "invalid flavor '$2', must be one of: retail, mainline, classic, mists, classic_era, vanilla, titan, wrath"
				exit 1
			fi
			shift
			;;
		--beta|-b)
			BETA=true
			;;
		--ptr|-p)
			TEST=true
			;;
		--depth|-d)
			if [[ "$2" =~ ^[0-9]+$ ]]; then
				DEPTH="$2"
			else
				echo 'invalid depth value'
				exit 1
			fi
			shift
			;;
		--)
			shift
			break
			;;
	esac
	shift
done

if [ -z "${FLAVORS[*]}" ]; then
	FLAVORS=('wow')
fi

declare -A version_cache
function get_version_cdn {
	local product="$1"

	if [ "${version_cache[$product]+x}" ]; then
		# version is cached
		echo "${version_cache[$product]}"
	else
		# grab version from CDN, get the version field
		local product_info
		product_info=""

		local retries
		retries=5
		until [ -n "$product_info" ]; do
			if [ "$retries" -lt '5' ]; then
				echo "No response from Blizzard, $((retries + 1)) attempts remaining" >&2
			fi

			product_info="$(curl -fsSL "https://us.version.battle.net/v2/products/$product/versions")"

			if [ "$((retries--))" -eq '0' ]; then
				echo "No response from Blizzard, no attempts remaining" >&2
				exit 1 # TODO: this won't exit the script
			fi
		done

		# grab version from info
		local version
		if [ "$product" = 'wow_classic_titan' ]; then
			version="$(awk -F'|' '/^cn\|/{print $6}' <<< "$product_info")"
		else
			version="$(awk -F'|' '/^us\|/{print $6}' <<< "$product_info")"
		fi

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

function get_versions {
	local product="$1"

	# get baseline version, stripping imaginary suffixes
	local versions=()
	# versions+=("$(get_version_cdn "${product/_legacy/}")")
	versions+=("$(get_version_cdn "${product}")")

	# check beta and test variations if applicable
	if $BETA; then
		if [ "$product" = 'wow' ]; then
			local version
			version="$(get_version_cdn 'wow_beta')"
			if ((version > versions[0] )); then
				versions+=("$version")
			fi
		elif [ "$product" = 'wow_classic' ]; then
			local version
			version="$(get_version_cdn 'wow_classic_beta')"
			if ((version > versions[0] )); then
				versions+=("$version")
			fi
		fi
	fi

	if $TEST; then
		if [ "$product" = 'wow' ]; then
			local version1
			version1="$(get_version_cdn 'wowt')" # PTR 1
			if ((version1 > versions[0] )); then
				versions+=("$version1")
			fi
			local version2
			version2="$(get_version_cdn 'wowxptr')" # PTR 2
			if ((version2 > versions[0] )); then
				versions+=("$version2")
			fi
		elif [ "$product" = 'wow_classic_era' ]; then
			local version
			version="$(get_version_cdn 'wow_classic_era_ptr')"
			if ((version > versions[0] )); then
				versions+=("$version")
			fi
		elif [ "$product" = 'wow_classic' ]; then
			local version
			version="$(get_version_cdn 'wow_classic_ptr')"
			if ((version > versions[0] )); then
				versions+=("$version")
			fi
		fi
	fi

	# output sorted versions without duplicates
	printf "%s\n" "${versions[@]}" | sort -un
}

function replace_line {
	local file="$1"
	local products="$2"
	local lineno="${3:-}"

	local all_versions
	all_versions=()

	for product in ${products//,/ }; do
		echo "Getting version for '$product' ..."

		# grab versions for this product
		local versions
		mapfile -t versions < <(get_versions "$product")

		for version in "${versions[@]}"; do
			all_versions+=("$version")
		done
	done

	if [ -n "${all_versions[*]}" ]; then
		# concatenate versions
		local interface
		interface="$(printf ", %s" "${all_versions[@]}")"

		# replace version(s) in-line, at specified line number if applicable
		sed -ri "${lineno%%:*}s/^(## Interface.*:)\s?.+/\1 ${interface:2}/" "$file"
	fi
}

function update {
	# store hash of file before we modify it
	local checksum
	checksum="$(md5sum "$file")"

	# check filename and replace if it matches
	if [[ "$file" =~ [_-](Mainline|Standard).toc$ ]]; then
		replace_line "$file" 'wow'
	elif [[ "$file" =~ [_-](Vanilla).toc$ ]]; then
		replace_line "$file" 'wow_classic_era'
	elif [[ "$file" =~ [_-](Classic|Mists).toc$ ]]; then
		replace_line "$file" 'wow_classic'
	elif [[ "$file" =~ [_-](Wrath).toc$ ]]; then
		replace_line "$file" 'wow_classic_titan'
	else
		# check multi-toc, passing the line number for each match
		if lineno=$(grep -nE '^## Interface:' "$file"); then
			flavors="$(printf '%s,' "${FLAVORS[@]}")"
			replace_line "$file" "${flavors%,}" "$lineno"
		fi
		if lineno=$(grep -nE '^## Interface-Vanilla:' "$file"); then
			replace_line "$file" 'wow_classic_era' "$lineno"
		fi
		if lineno=$(grep -nE '^## Interface-Classic:' "$file"); then
			replace_line "$file" 'wow_classic' "$lineno"
		fi
		if lineno=$(grep -nE '^## Interface-Mists:' "$file"); then
			replace_line "$file" 'wow_classic' "$lineno"
		fi
		if lineno=$(grep -nE '^## Interface-Wrath:' "$file"); then
			replace_line "$file" 'wow_classic_titan' "$lineno"
		fi
	fi

	# compare with new hash and output status
	if [[ "$(md5sum "$file")" != "$checksum" ]]; then
		echo "Updated $file"
	else
		echo "No changes to $file"
	fi
}

while read -r file; do
	update "$file"
done < <(find . -maxdepth "$DEPTH" -type f -iname '*.toc' | sed 's/^.\///')
