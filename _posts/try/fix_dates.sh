#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./fix_dates.sh file1.md file2.md file3.md
#
# For each .md file, finds the first line like:
#   date: 2026-04
#
# but not:
#   date: 2026-04-15
#
# and replaces it with:
#   date: 2026-04-01

for file in "$@"; do
  if [[ ! -f "$file" ]]; then
    echo "Skipping: not a file: $file" >&2
    continue
  fi

  if [[ "$file" != *.md ]]; then
    echo "Skipping: not an .md file: $file" >&2
    continue
  fi

  perl -0pi -e '
    s/^date:\s*([0-9]{4}-[0-9]{2})(?!-[0-9]{2})(.*)$/date: $1-01$2/m
  ' "$file"

  echo "Processed: $file"
done
