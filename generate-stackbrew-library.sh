#!/usr/bin/env bash
set -Eeuo pipefail

declare -A aliases=(
	[15]='latest'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

# sort version numbers with highest first
IFS=$'\n'; set -- $(sort -rV <<<"$*"); unset IFS

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		files="$(
			git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						if ($i ~ /^--from=/) {
							next
						}
						print $i
					}
				}
			'
		)"
		fileCommit Dockerfile $files
	)
}

getArches() {
	local repo="$1"; shift
	local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'

	eval "declare -g -A parentRepoToArches=( $(
		find -name 'Dockerfile' -exec awk '
				toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|.*\/.*)(:|$)/ {
					print "'"$officialImagesUrl"'" $2
				}
			' '{}' + \
			| sort -u \
			| xargs bashbrew cat --format '[{{ .RepoName }}:{{ .TagName }}]="{{ join " " .TagEntry.Architectures }}"'
	) )"
}
getArches 'postgres'

cat <<-EOH
# this file is generated via https://github.com/docker-library/postgres/blob/$(fileCommit "$self")/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon),
             Joseph Ferguson <yosifkit@gmail.com> (@yosifkit)
GitRepo: https://github.com/docker-library/postgres.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version; do
	export version

	variants="$(jq -r '.[env.version].variants | map(@sh) | join(" ")' versions.json)"
	eval "variants=( $variants )"

	alpine="$(jq -r '.[env.version].alpine' versions.json)"
	debian="$(jq -r '.[env.version].debian' versions.json)"

	fullVersion="$(jq -r '.[env.version].version' versions.json)"

	# ex: 9.6.22, 13.3, or 14beta2
	versionAliases=(
		$fullVersion
	)
	# skip unadorned "version" on prereleases: https://www.postgresql.org/developer/beta/
	# ex: 9.6, 13, or 14
	case "$fullVersion" in
		*alpha* | *beta* | *rc*) ;;
		*) versionAliases+=( $version ) ;;
	esac
	# ex: 9 or latest
	versionAliases+=(
		${aliases[$version]:-}
	)

	for variant in "${variants[@]}"; do
		dir="$version/$variant"
		commit="$(dirCommit "$dir")"

		parent="$(awk 'toupper($1) == "FROM" { print $2 }' "$dir/Dockerfile")"
		arches="${parentRepoToArches[$parent]}"

		variantAliases=( "${versionAliases[@]/%/-$variant}" )
		variantAliases=( "${variantAliases[@]//latest-/}" )

		case "$variant" in
			"$debian")
				variantAliases=(
					"${versionAliases[@]}"
					"${variantAliases[@]}"
				)
				;;
			alpine"$alpine")
				variantAliases+=( "${versionAliases[@]/%/-alpine}" )
				variantAliases=( "${variantAliases[@]//latest-/}" )
				;;
		esac

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: $(join ', ' $arches)
			GitCommit: $commit
			Directory: $dir
		EOE
	done
done
