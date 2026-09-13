#!/usr/bin/env bash
# Run interactively: restic asks for its independent backup password.
set -euo pipefail
if [[ $# != 1 || "$1" != /* ]]; then
  echo 'Usage: backup-home.sh /absolute/path/on/backup-disk/restic-repository' >&2
  exit 2
fi
backup_repo=$(realpath -m -- "$1")
case "$backup_repo/" in
  "$HOME/"*) echo 'Choose a backup destination outside the home being backed up.' >&2; exit 2 ;;
esac
backup_parent=$(dirname -- "$backup_repo")
if [[ ! -d "$backup_parent" ]]; then
  echo 'Mount the backup disk and create the parent directory first.' >&2
  exit 2
fi
if [[ $(stat -c %d -- "$backup_parent") == $(stat -c %d -- "$HOME") ]]; then
  echo 'The backup destination must be on a different filesystem from your home.' >&2
  exit 2
fi
umask 077
export RESTIC_REPOSITORY="$backup_repo"
if [[ ! -e "$backup_repo/config" ]]; then restic init; fi
# Includes ~/.config/sops/age/keys.txt, browser profiles, code and application data.
# Cache-tagged directories and trash are rebuildable. Other mounted filesystems
# need their own backup; --one-file-system avoids traversing network/FUSE mounts.
restic backup "$HOME" --one-file-system --exclude-caches \
  --exclude "$HOME/.cache" --exclude "$HOME/.local/share/Trash" --tag nixos-home
restic check
restic snapshots --latest 1
