#!/usr/bin/env bash
set -Eeuo pipefail

# we will support at most two entries in each of these lists, and both should be in descending order
supportedDebianSuites=(
	bookworm
	bullseye
)
supportedAlpineVersions=(
	3.18
	3.17
)
defaultDebianSuite="${supportedDebianSuites[0]}"
declare -A debianSuites=(
	[11]='' # https://github.com/docker-library/postgres/issues/582 😬
)
defaultAlpineVersion="${supportedAlpineVersions[0]}"
declare -A alpineVersions=(
	#[14]='3.16'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

packagesBase='http://apt.postgresql.org/pub/repos/apt/dists/'
declare -A suitePackageList=() suiteVersionPackageList=() suiteArches=()
_raw_package_list() {
	local suite="$1"; shift
	local component="$1"; shift
	local arch="$1"; shift

	curl -fsSL "$packagesBase/$suite-pgdg/$component/binary-$arch/Packages.bz2" | bunzip2
}
fetch_suite_package_list() {
	local -; set +x # make sure running with "set -x" doesn't spam the terminal with the raw package lists

	local suite="$1"; shift
	local version="$1"; shift
	local arch="$1"; shift

	# normal (GA) releases end up in the "main" component of upstream's repository
	if [ -z "${suitePackageList["$suite-$arch"]:+isset}" ]; then
		local suiteArchPackageList
		suiteArchPackageList="$(_raw_package_list "$suite" 'main' "$arch")"
		suitePackageList["$suite-$arch"]="$suiteArchPackageList"
	fi

	# ... but pre-release versions (betas, etc) end up in the "PG_MAJOR" component (so we need to check both)
	if [ -z "${suiteVersionPackageList["$suite-$version-$arch"]:+isset}" ]; then
		local versionPackageList
		versionPackageList="$(_raw_package_list "$suite" "$version" "$arch")"
		suiteVersionPackageList["$suite-$version-$arch"]="$versionPackageList"
	fi
}
awk_package_list() {
	local suite="$1"; shift
	local version="$1"; shift
	local arch="$1"; shift

	awk -F ': ' -v version="$version" "$@" <<<"${suitePackageList["$suite-$arch"]}"$'\n'"${suiteVersionPackageList["$suite-$version-$arch"]}"
}
fetch_suite_arches() {
	local suite="$1"; shift

	if [ -z "${suiteArches["$suite"]:+isset}" ]; then
		local suiteRelease
		suiteRelease="$(curl -fsSL "$packagesBase/$suite-pgdg/Release")"
		suiteArches["$suite"]="$(gawk <<<"$suiteRelease" -F ':[[:space:]]+' '$1 == "Architectures" { print $2; exit }')"
	fi
}

for version in "${versions[@]}"; do
	export version

	versionAlpineVersion="${alpineVersions[$version]:-$defaultAlpineVersion}"
	versionDebianSuite="${debianSuites[$version]-$defaultDebianSuite}" # intentionally missing ":" so it can be empty (again, https://github.com/docker-library/postgres/issues/582 😭)
	export versionAlpineVersion versionDebianSuite

	doc="$(jq -nc '{
		alpine: env.versionAlpineVersion,
		debian: env.versionDebianSuite,
	}')"

	fullVersion=
	for suite in "${supportedDebianSuites[@]}"; do
		fetch_suite_package_list "$suite" "$version" 'amd64'
		suiteVersions="$(awk_package_list "$suite" "$version" 'amd64' '
			$1 == "Package" { pkg = $2 }
			$1 == "Version" && pkg == "postgresql-" version { print $2 }
		' | sort -V)"
		suiteVersion="$(tail -1 <<<"$suiteVersions")" # "15~beta4-1.pgdg110+1"
		srcVersion="${suiteVersion%%-*}" # "15~beta4"
		tilde='~'
		srcVersion="${srcVersion//$tilde/}" # "15beta4"
		[ -n "$fullVersion" ] || fullVersion="$srcVersion"
		if [ "$fullVersion" != "$srcVersion" ]; then
			echo >&2 "warning: $version should be '$fullVersion' but $suite has '$srcVersion' ($suiteVersion)"
			continue
		fi

		versionArches='[]'
		fetch_suite_arches "$suite"
		for arch in ${suiteArches["$suite"]}; do
			fetch_suite_package_list "$suite" "$version" "$arch"
			archVersion="$(awk_package_list "$suite" "$version" "$arch" '
				$1 == "Package" { pkg = $2 }
				$1 == "Version" && pkg == "postgresql-" version { print $2; exit }
			')"
			if [ "$archVersion" = "$suiteVersion" ]; then
				versionArches="$(jq <<<"$versionArches" -c --arg arch "$arch" '. += [$arch]')"
			fi
		done

		export suite suiteVersion
		doc="$(jq <<<"$doc" -c --argjson arches "$versionArches" '
			.[env.suite] = {
				version: env.suiteVersion,
				arches: $arches,
			}
			| .variants += [ env.suite ]
		')"
	done

	for alpineVersion in "${supportedAlpineVersions[@]}"; do
		doc="$(jq <<<"$doc" -c --arg v "$alpineVersion" '
			.variants += [ "alpine" + $v ]
		')"
	done

	sha256="$(
		curl -fsSL "https://ftp.postgresql.org/pub/source/v${fullVersion}/postgresql-${fullVersion}.tar.bz2.sha256" \
			| cut -d' ' -f1
	)"

	echo "$version: $fullVersion"

	export fullVersion sha256 major="${version%%.*}"
	json="$(jq <<<"$json" -c --argjson doc "$doc" '
		.[env.version] = ($doc + {
			version: env.fullVersion,
			sha256: env.sha256,
			major: (env.major | tonumber),
		})
	')"
done

jq <<<"$json" -S . > versions.json
