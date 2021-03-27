#!/bin/bash

gameVersions="$(curl -sSLH"X-API-Token: $CF_API_KEY" "https://wow.curseforge.com/api/game/versions")"
retailVersion="$(jq -r 'map(select(.gameVersionTypeID == 517)) | max_by(.id) | .name' <<< "$gameVersions")"
classicVersion="$(jq -r 'map(select(.gameVersionTypeID == 67408)) | max_by(.id) | .name' <<< "$gameVersions")"

interfaceVersions="$(curl -sSLH"X-API-Token: $WOWI_API_TOKEN" "https://api.wowinterface.com/addons/compatible.json")"
retailInterfaceVersion="$(jq -r '.[] | select(.id == "'"$retailVersion"'") | .interface' <<< "$interfaceVersions")"
classicInterfaceVersion="$(jq -r '.[] | select(.id == "'"$classicVersion"'") | .interface' <<< "$interfaceVersions")"

while read -r file; do
	# TODO: check/output if we actully made any changes
	sed -ri 's/^(## Interface: ).*$/\1'"$retailInterfaceVersion"'/' "$file"
	sed -ri 's/^(## Interface-Retail: ).*$/\1'"$retailInterfaceVersion"'/' "$file"
	sed -ri 's/^(## Interface-Classic: ).*$/\1'"$classicInterfaceVersion"'/' "$file"
done < <(find . -name '*.toc')
