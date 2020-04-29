#!/usr/bin/env bash
set -Eeuo pipefail

# copy all the Debian build jobs into "force deb build" jobs which build like architectures upstream doesn't publish for will
jq \
	--arg prefix '[ "$(dpkg --print-architecture)" = "amd64" ]' \
	--arg dfMunge 'grep -qE "amd64 [|] " "$df"; sed -ri -e "s/amd64 [|] //g" "$df"; ! grep -qE "amd64 [|] " "$df"' \
	'
		.matrix.include += [
			.matrix.include[]
			| select(.name | test(" (.+)") | not) # ignore any existing munged builds
			| select(.meta.froms[] | test("^debian:|^ubuntu:"))
			| .name += " (force deb build)"
			| .runs.build = (
				[
					"# force us to build debs instead of downloading them",
					$prefix,
					("for df in " + ([ .meta.dockerfiles[] | @sh ] | join(" ")) + "; do " + $dfMunge + "; done"),
					.runs.build
				] | join ("\n")
			)
		]
	' "$@"
