# shellcheck shell=bash
# Used by writeShellApplication (errexit, nounset, pipefail).
# Arguments: file, JSON path array, desired JSON value.
file=$1
json_path=$2
value=$3
umask 077
mkdir -p -- "$(dirname -- "$file")"
snapshot=$(mktemp "$file.snapshot.XXXXXX")
candidate=""
cleanup() {
  rm -f -- "$snapshot"
  if [ -n "$candidate" ]; then rm -f -- "$candidate"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

existed=false
if [ -e "$file" ] || [ -L "$file" ]; then
  existed=true
  cat -- "$file" > "$snapshot"
else
  printf '{}\n' > "$snapshot"
fi

# Empty files, scalars, arrays and multiple JSON documents are not settings objects.
# Preserve the original and a private recovery copy; never reset user permissions
# or MCP settings just to install our optional integration.
if ! jq -e -s 'length == 1 and (.[0] | type == "object")' "$snapshot" >/dev/null 2>&1; then
  backup=$(mktemp "$file.invalid.XXXXXX")
  cat -- "$snapshot" > "$backup"
  echo "Invalid JSON settings left unchanged: $file (backup: $backup)" >&2
  exit 0
fi

if jq -e --argjson path "$json_path" --argjson value "$value" \
    'getpath($path) == $value' "$snapshot" >/dev/null 2>&1; then
  exit 0
fi
candidate=$(mktemp "$file.tmp.XXXXXX")
jq --argjson path "$json_path" --argjson value "$value" \
  'setpath($path; $value)' "$snapshot" > "$candidate"

# Avoid overwriting a change noticed while preparing the update. This is an
# optimistic check, not a lock shared with Claude Code; keep activation brief.
if $existed; then
  if ! cmp -s -- "$file" "$snapshot"; then
    echo "Settings changed concurrently; skipping update: $file" >&2
    exit 0
  fi
elif [ -e "$file" ] || [ -L "$file" ]; then
  echo "Settings appeared concurrently; skipping update: $file" >&2
  exit 0
fi
mv -f -- "$candidate" "$file"
