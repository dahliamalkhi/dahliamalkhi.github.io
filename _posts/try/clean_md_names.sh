#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./clean_md_names.sh file1.md file2.md file3.md
#
# Example:
#   ./clean_md_names.sh 2024-10-01-word1-word2.md 2026-03-01-w1-w2-w3-w4.md
#
# For each .md file:
#   1. Extract the first word after yyyy-mm-dd-
#   2. Replace patterns like 2024-S1 or 2019-S2 inside the file with that first word
#   3. Rename the file to yyyy-mm-dd-firstword.md

for file in "$@"; do
  if [[ ! -f "$file" ]]; then
    echo "Skipping: not a file: $file" >&2
    continue
  fi

  if [[ "$file" != *.md ]]; then
    echo "Skipping: not an .md file: $file" >&2
    continue
  fi

  dir=$(dirname "$file")
  base=$(basename "$file")

  # Match filenames of the form:
  # yyyy-mm-dd-word1-word2-... .md
  if [[ "$base" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-([^-]+)(-.*)?\.md$ ]]; then
    date_part="${BASH_REMATCH[1]}"
    first_word="${BASH_REMATCH[2]}"
  else
    echo "Skipping: filename does not match yyyy-mm-dd-word...md pattern: $file" >&2
    continue
  fi

  # Replace patterns like 2024-S1, 2019-S2, 2026-S3, etc.
  # Pattern: 20[0-9][0-9]-S[0-9]+
  perl -pi -e "s/20[0-9]{2}-S[0-9]+/$first_word/g" "$file"

  newbase="${date_part}-${first_word}.md"
  newfile="${dir}/${newbase}"

  if [[ "$file" == "$newfile" ]]; then
    echo "Already clean: $file"
    continue
  fi

  if [[ -e "$newfile" ]]; then
    echo "Skipping rename: target already exists: $newfile" >&2
    continue
  fi

  echo "Renaming: $file -> $newfile"
  mv -- "$file" "$newfile"
done
