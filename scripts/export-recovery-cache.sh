#!/usr/bin/env bash
# Save flake inputs, the proprietary .deb and the built package with dependencies.
set -euo pipefail
if [[ $# != 1 || "$1" != /* ]]; then
  echo 'Usage: export-recovery-cache.sh /absolute/path/on/backup-disk/cache-directory' >&2
  exit 2
fi
cd "$(git rev-parse --show-toplevel)"
if [[ -n $(git status --porcelain --untracked-files=all) ]]; then
  echo 'Commit repository changes first so the cache has an exact Git revision.' >&2
  exit 1
fi
umask 077
cache_root=$(realpath -m -- "$1")
mkdir -p -- "$cache_root"
cache_url=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).as_uri())' "$cache_root/store")
revision=$(git rev-parse HEAD)
# Include the source .deb explicitly: it is not part of the runtime closure.
build_output=$(nix build --no-link --print-out-paths --no-write-lock-file \
  .#packages.x86_64-linux.chatgpt .#packages.x86_64-linux.chatgpt.src)
mapfile -t package_paths <<< "$build_output"
if [[ ${#package_paths[@]} != 2 ]]; then
  echo 'Could not build both ChatGPT and its source; cache export aborted.' >&2
  exit 1
fi
nix flake archive --no-write-lock-file --to "$cache_url" .
nix copy --to "$cache_url" "${package_paths[@]}"
git bundle create "$cache_root/repository-$revision.bundle" --all
git bundle verify "$cache_root/repository-$revision.bundle"
printf '%s\n' "${package_paths[@]}" > "$cache_root/paths-$revision.txt"
printf 'Git revision: %s\nCache: %s\n' "$revision" "$cache_url"
