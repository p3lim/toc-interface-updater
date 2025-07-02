#!/bin/bash

set -o errexit -o pipefail

function usage {
	cat << EOF
$0 [OPTIONS]

Options:
  --beta, -b    Include beta versions
  --ptr, -p     Include test versions
  --flavor, -f  Fallback game flavor (retail/classic/vanilla)
  --depth, -d   Set max recursion into subdirectories
  --help, -h    Show this help text
EOF
}

BETA=false
TEST=false
DEFAULT='wow'
DEPTH='99'

args="$(getopt -n "$0" -l 'help,flavor:,beta,ptr,depth:' -o 'hf:bpd:' -- "$@")"
eval set -- "$args"

while [ $# -ge 1 ]; do
	case "$1" in
		--help|-h)
			usage
			exit 0
			;;
		--flavor|-f)
			# TODO: support multiple flavors at the same time
			if [[ "${2,,}" =~ (retail|mainline) ]]; then
				DEFAULT='wow'
			elif [[ "${2,,}" =~ (classic_era|vanilla) ]]; then
				DEFAULT='wow_classic_era'
			elif [[ "${2,,}" =~ (classic|mists) ]]; then
				DEFAULT='wow_classic'
			else
				echo "invalid flavor '$2', must be one of: retail, mainline, classic, cata, mists, classic_era, vanilla."
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

declare -A version_cache
function get_version_cdn {
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

	# make sure we don't get duplicates
	mapfile -t versions < <(printf "%s\n" "${versions[@]}" | sort -un)

	echo "${versions[@]}"
}

function replace_line {
	local file="$1"
	local product="$2"
	local lineno="$3"

	# grab versions for this product
	local versions
	# shellcheck disable=SC2207
	versions=($(get_versions "$product"))

	# concatinate versions
	local interface
	interface="$(printf ", %s" "${versions[@]}")"

	# replace version(s) in-line, at specified line number if applicable
	sed -ri "${lineno%%:*}s/^(## Interface.*:)\s?.+/\1 ${interface:2}/" "$file"
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
	else
		# check multi-toc, passing the line number for each match
		if lineno=$(grep -nE '^## Interface:' "$file"); then
			replace_line "$file" "$DEFAULT" "$lineno"
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
