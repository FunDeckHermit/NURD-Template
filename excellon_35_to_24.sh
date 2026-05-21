#!/bin/bash

# Auto-convert the single .drl file in current dir from 3.5 to 2.4 format (INCH)
# Output: <original>_fix.drl

# Find all .drl files (case-insensitive)
shopt -s nullglob nocaseglob
drl_files=(*.drl)

# Check count
if [ "${#drl_files[@]}" -eq 0 ]; then
    echo "Error: No .drl file found in current directory." >&2
    exit 1
elif [ "${#drl_files[@]}" -gt 1 ]; then
    echo "Error: Multiple .drl files found. Please ensure only one exists:" >&2
    printf '  - %s\n' "${drl_files[@]}" >&2
    exit 1
fi

INPUT="${drl_files[0]}"
# Insert "_fix" before .drl extension
OUTPUT="${INPUT%.drl}_fix.drl"

echo "Found input file: $INPUT"
echo "Output will be:   $OUTPUT"
echo "Converting 3.5 → 2.4 format..."

# Create clean LF-only temp file
TMPFILE=$(mktemp)
tr -d '\r' < "$INPUT" > "$TMPFILE"

awk '
{
    line = $0
    if (line ~ /^[Xx][0-9]{8}[Yy][0-9]{8}/) {
        x8 = substr(line, 2, 8)
        y8 = substr(line, 11, 8)
        # Round after dividing by 10
        x24 = int((x8 + 0) / 10 + 0.5)
        y24 = int((y8 + 0) / 10 + 0.5)
        printf "X%06dY%06d\n", x24, y24
    } else {
        print line
    }
}
' "$TMPFILE" > "$OUTPUT"

rm -f "$TMPFILE"
echo "✅ Done! Output: $OUTPUT"
