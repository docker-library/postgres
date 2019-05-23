#!/bin/bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

# sort version numbers with highest last (so it goes first in .travis.yml)
IFS=$'\n'; versions=( $(echo "${versions[*]}" | sort -V) ); unset IFS

defaultDebianSuite='stretch-slim'
declare -A debianSuite=(
	#[9.6]='jessie'
)
defaultAlpineVersion='3.9'
declare -A alpineVersion=(
	#[9.6]='3.5'
)

packagesBase='http://apt.postgresql.org/pub/repos/apt/dists/'

# https://www.mirrorservice.org/sites/ftp.ossp.org/pkg/lib/uuid/?C=M;O=D
osspUuidVersion='1.6.2'
osspUuidHash='11a615225baa5f8bb686824423f50e4427acd3f70d394765bdff32801f0fd5b0'

declare -A suitePackageList=() suiteArches=()
travisEnv=
for version in "${versions[@]}"; do
	tag="${debianSuite[$version]:-$defaultDebianSuite}"
	suite="${tag%%-slim}"
	if [ -z "${suitePackageList["$suite"]:+isset}" ]; then
		suitePackageList["$suite"]="$(curl -fsSL "${packagesBase}/${suite}-pgdg/main/binary-amd64/Packages.bz2" | bunzip2)"
	fi
	if [ -z "${suiteArches["$suite"]:+isset}" ]; then
		suiteArches["$suite"]="$(curl -fsSL "${packagesBase}/${suite}-pgdg/Release" | gawk -F ':[[:space:]]+' '$1 == "Architectures" { gsub(/[[:space:]]+/, "|", $2); print $2 }')"
	fi

	versionList="$(echo "${suitePackageList["$suite"]}"; curl -fsSL "${packagesBase}/${suite}-pgdg/${version}/binary-amd64/Packages.bz2" | bunzip2)"
	fullVersion="$(echo "$versionList" | awk -F ': ' '$1 == "Package" { pkg = $2 } $1 == "Version" && pkg == "postgresql-'"$version"'" { print $2; exit }' || true)"
	majorVersion="${version%%.*}"

	echo "$version: $fullVersion"

	cp docker-entrypoint.sh "$version/"
	sed -e 's/%%PG_MAJOR%%/'"$version"'/g;' \
		-e 's/%%PG_VERSION%%/'"$fullVersion"'/g' \
		-e 's/%%DEBIAN_TAG%%/'"$tag"'/g' \
		-e 's/%%DEBIAN_SUITE%%/'"$suite"'/g' \
		-e 's/%%ARCH_LIST%%/'"${suiteArches["$suite"]}"'/g' \
		Dockerfile-debian.template > "$version/Dockerfile"
	if [ "$majorVersion" = '9' ]; then
		sed -i -e 's/WALDIR/XLOGDIR/g' \
			-e 's/waldir/xlogdir/g' \
			"$version/docker-entrypoint.sh"
		# ICU support was introduced in PostgreSQL 10 (https://www.postgresql.org/docs/10/static/release-10.html#id-1.11.6.9.5.13)
		sed -i -e '/icu/d' "$version/Dockerfile"
	else
		# postgresql-contrib-10 package does not exist, but is provided by postgresql-10
		# Packages.gz:
		# Package: postgresql-10
		# Provides: postgresql-contrib-10
		sed -i -e '/postgresql-contrib-/d' "$version/Dockerfile"
	fi

	# TODO figure out what to do with odd version numbers here, like release candidates
	srcVersion="${fullVersion%%-*}"
	# change "10~beta1" to "10beta1" for ftp urls
	tilde='~'
	srcVersion="${srcVersion//$tilde/}"
	srcSha256="$(curl -fsSL "https://ftp.postgresql.org/pub/source/v${srcVersion}/postgresql-${srcVersion}.tar.bz2.sha256" | cut -d' ' -f1)"
	for variant in alpine; do
		if [ ! -d "$version/$variant" ]; then
			continue
		fi

		cp docker-entrypoint.sh "$version/$variant/"
		sed -i 's/gosu/su-exec/g' "$version/$variant/docker-entrypoint.sh"
		sed -e 's/%%PG_MAJOR%%/'"$version"'/g' \
			-e 's/%%PG_VERSION%%/'"$srcVersion"'/g' \
			-e 's/%%PG_SHA256%%/'"$srcSha256"'/g' \
			-e 's/%%ALPINE-VERSION%%/'"${alpineVersion[$version]:-$defaultAlpineVersion}"'/g' \
			"Dockerfile-$variant.template" > "$version/$variant/Dockerfile"
		if [ "$majorVersion" = '9' ]; then
			sed -i -e 's/WALDIR/XLOGDIR/g' \
				-e 's/waldir/xlogdir/g' \
				"$version/$variant/docker-entrypoint.sh"
			# ICU support was introduced in PostgreSQL 10 (https://www.postgresql.org/docs/10/static/release-10.html#id-1.11.6.9.5.13)
			sed -i -e '/icu/d' "$version/$variant/Dockerfile"
		fi

		if [ "$majorVersion" -gt 11 ]; then
			sed -i '/backwards compat/d' "$version/$variant/Dockerfile"
		fi

		travisEnv="\n  - VERSION=$version VARIANT=$variant$travisEnv"
	done

	for variant in windows; do
		if [ ! -d "$version/$variant" ]; then
			continue
		fi

		edbRepository='https://get.enterprisedb.com/postgresql'

		cp docker-entrypoint.cmd "$version/$variant/docker-entrypoint.cmd"
		cp Dockerfile-windows.template "$version/$variant/Dockerfile"

		case "$version" in
			9.4)
				edbVersion='9.4.22-1'
				# Visual C++ 2013 Redistributable Package
				edbVCRedist='https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe'
				;;
			9.5)
				edbVersion='9.5.17-1'
				# Visual C++ 2013 Redistributable Package
				edbVCRedist='https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe'
				;;
			9.6)
				edbVersion='9.6.13-1'
				# Visual C++ 2013 Redistributable Package
				edbVCRedist='https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe'
				;;
			10)
				edbVersion='10.8-1'
				# Visual C++ 2013 Redistributable Package
				edbVCRedist='https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe'
				;;
			11)
				edbVersion='11.3-1'
				# Visual C++ 2017 Redistributable Package
				edbVCRedist='https://download.visualstudio.microsoft.com/download/pr/11100230/15ccb3f02745c7b206ad10373cbca89b/VC_redist.x64.exe'
				;;
		esac
		sed -e 's|%%EDB_VERSION%%|'"$edbVersion"'|g' \
			-e 's|%%EDB_REPOSITORY%%|'"$edbRepository"'|g' \
			-e 's|%%EDB_VCREDIST%%|'"$edbVCRedist"'|g' \
			"Dockerfile-$variant.template" > "$version/$variant/Dockerfile"
	done

	travisEnv="\n  - VERSION=$version FORCE_DEB_BUILD=1$travisEnv"
	travisEnv="\n  - VERSION=$version$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
