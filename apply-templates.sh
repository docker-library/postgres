#!/usr/bin/env bash
set -Eeuo pipefail

[ -f versions.json ] # run "versions.sh" first

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

jqt='.jq-template.awk'
if [ -n "${BASHBREW_SCRIPTS:-}" ]; then
	jqt="$BASHBREW_SCRIPTS/jq-template.awk"
elif [ "$BASH_SOURCE" -nt "$jqt" ]; then
	# https://github.com/docker-library/bashbrew/blob/master/scripts/jq-template.awk
	wget -qO "$jqt" 'https://github.com/docker-library/bashbrew/raw/00e281f36edd19f52541a6ba2f215cc3c4645128/scripts/jq-template.awk'
fi

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

generated_warning() {
	cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#

	EOH
}

for version; do
	export version

	major="$(jq -r '.[env.version].major' versions.json)"

	variants="$(jq -r '.[env.version].debianSuites + ["alpine"] | map(@sh) | join(" ")' versions.json)"
	eval "variants=( $variants )"

	rm -rf "$version"

	for variant in "${variants[@]}"; do
		export variant

		dir="$version/$variant"
		mkdir -p "$dir"

		echo "processing $dir ..."

		if [ "$variant" = 'alpine' ]; then
			template='Dockerfile-alpine.template'
		else
			template='Dockerfile-debian.template'
		fi
		{
			generated_warning
			gawk -f "$jqt" "$template"
		} > "$dir/Dockerfile"

		cp -a docker-entrypoint.sh "$dir/"
		if [ "$major" = '9' ]; then
			sed -i -e 's/WALDIR/XLOGDIR/g' -e 's/waldir/xlogdir/g' "$dir/docker-entrypoint.sh"
		fi
		if [ "$variant" = 'alpine' ]; then
			sed -i -e 's/gosu/su-exec/g' "$dir/docker-entrypoint.sh"
		fi
	done
done
