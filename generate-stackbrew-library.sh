#!/bin/bash
set -e

declare -A aliases
aliases=(
	[9.3]='latest 9'
	[8.4]='8'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )
commit="$(git log -1 --format='format:%H')"
url='git://github.com/docker-library/postgres'

echo '# maintainer: InfoSiftr <github@infosiftr.com> (@infosiftr)'

for version in "${versions[@]}"; do
	fullVersion="$(grep -m1 'ENV PG_VERSION ' "$version/Dockerfile" | cut -d' ' -f3 | cut -d- -f1 | sed 's/~/-/g')"
	versionAliases=( ${aliases[$version]} $version $fullVersion )
	
	echo
	for va in "${versionAliases[@]}"; do
		echo "$va: ${url}@${commit} $version"
	done
done
