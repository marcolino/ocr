#!/usr/bin/env bash
#
# De-hyphenate text at line breaks, skip hyphens at empty lines
# Usage: ./dehyphen.sh input.txt output.txt

INPUT="$1"
OUTPUT="$2"

if [[ -z "$INPUT" || -z "$OUTPUT" ]]; then
  echo "Usage: $0 input.txt output.txt"
  exit 1
fi

# Read entire file as a stream (-z)
# Replace hyphen+newline only if next line is not empty
# Join hyphenated word, insert newline after joined word
sed -z 's/\([^\n]\)-\n\([^\n][^ ]*\) \?/\1\2\n/g' "$INPUT" > "$OUTPUT"