#!/usr/bin/env bash
# Build or serve docs/ with the same gem set GitHub Pages uses, in a container so no local
# Ruby is needed.
#
#   scripts/serve_docs.sh          serve at http://localhost:4000 with live reload
#   scripts/serve_docs.sh build    build once into docs/_site and exit
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docs_dir="$repo_root/docs"
mode="${1:-serve}"
image="docker.io/ruby:3.3-slim"

if command -v podman >/dev/null 2>&1; then
	runtime=podman
elif command -v docker >/dev/null 2>&1; then
	runtime=docker
else
	printf 'ERROR: needs podman or docker.\n' >&2
	exit 1
fi

# Bundler and the gem cache live in a named volume so a rebuild does not refetch every gem.
setup='
set -e
if ! command -v gcc >/dev/null 2>&1; then
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq >/dev/null 2>&1
	apt-get install -y -qq build-essential git >/dev/null 2>&1
fi
gem list -i bundler >/dev/null 2>&1 || gem install bundler -N >/dev/null
bundle config set --local path /gems >/dev/null
bundle install --quiet
'

case "$mode" in
	build)
		command="$setup bundle exec jekyll build --destination /srv/jekyll/_site"
		ports=()
		;;
	serve)
		command="$setup bundle exec jekyll serve --host 0.0.0.0 --port 4000 --livereload --livereload-port 35729 --destination /srv/jekyll/_site"
		ports=(-p 4000:4000 -p 35729:35729)
		printf 'Serving docs at http://localhost:4000 (Ctrl-C to stop)\n'
		;;
	*)
		printf 'Usage: %s [serve|build]\n' "${BASH_SOURCE[0]}" >&2
		exit 1
		;;
esac

exec "$runtime" run --rm -it \
	-v "$docs_dir":/srv/jekyll:Z \
	-v godot-box3d-docs-gems:/gems \
	-w /srv/jekyll \
	"${ports[@]+"${ports[@]}"}" \
	"$image" bash -lc "$command"
