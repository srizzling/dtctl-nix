#!/usr/bin/env bash
#
# Repin sources.json to the latest upstream dtctl release.
#
# Upstream publishes a checksums.txt alongside every release, so this never
# needs to download the ~10 MB tarballs or run nix-prefetch — it reads all
# four hashes out of a single 1 KB file.
#
# Writes `changed`, `version` and `previous` to $GITHUB_OUTPUT when running
# under GitHub Actions. Exits 0 whether or not anything changed; check the
# `changed` output rather than the exit status.

set -euo pipefail

readonly UPSTREAM="dynatrace-oss/dtctl"

SOURCES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sources.json"
readonly SOURCES

# Nix system double -> goreleaser asset suffix.
declare -A TARGETS=(
  [aarch64-darwin]=darwin_arm64
  [x86_64-darwin]=darwin_amd64
  [aarch64-linux]=linux_arm64
  [x86_64-linux]=linux_amd64
)

log() { printf '%s\n' "$*" >&2; }

emit() {
  [[ -n "${GITHUB_OUTPUT:-}" ]] && printf '%s=%s\n' "$1" "$2" >>"$GITHUB_OUTPUT"
  return 0
}

# GITHUB_TOKEN lifts the anonymous API rate limit; works fine without it.
api() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$@"
  else
    curl -fsSL "$@"
  fi
}

current=$(jq -r '.version' "$SOURCES")

latest=$(api "https://api.github.com/repos/$UPSTREAM/releases/latest" | jq -r '.tag_name')
version="${latest#v}"

if [[ -z "$version" || "$version" == "null" ]]; then
  log "could not determine the latest release of $UPSTREAM"
  exit 1
fi

emit version "$version"
emit previous "$current"

if [[ "$version" == "$current" ]]; then
  log "dtctl is already pinned at $current"
  emit changed false
  exit 0
fi

log "dtctl $current -> $version"

checksums=$(curl -fsSL "https://github.com/$UPSTREAM/releases/download/v$version/checksums.txt")

assets='{}'
for system in "${!TARGETS[@]}"; do
  file="dtctl_${version}_${TARGETS[$system]}.tar.gz"

  # Match the whole line so the .sbom.json entry for the same target
  # cannot be picked up instead.
  sha=$(awk -v f="$file" '$2 == f { print $1 }' <<<"$checksums")

  if [[ -z "$sha" ]]; then
    log "no checksum for $file — upstream may have changed its asset naming"
    exit 1
  fi

  assets=$(jq \
    --arg system "$system" \
    --arg url "https://github.com/$UPSTREAM/releases/download/v$version/$file" \
    --arg sha256 "$sha" \
    '.[$system] = { url: $url, sha256: $sha256 }' \
    <<<"$assets")

  log "  $system  $sha"
done

# -S keeps key order stable regardless of associative-array iteration order,
# so a version bump diffs as four hashes rather than a reshuffled file.
jq -S -n --arg version "$version" --argjson assets "$assets" \
  '{ version: $version, assets: $assets }' >"$SOURCES.tmp"
mv "$SOURCES.tmp" "$SOURCES"

log "wrote $SOURCES"
emit changed true
