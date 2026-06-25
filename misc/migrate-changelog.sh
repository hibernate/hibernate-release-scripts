#!/usr/bin/env -S bash -e

########################################################################################################################
# Migrates a changelog.txt (plain text format) to changelog.md (Markdown format).
#
# Usage: migrate-changelog.sh <changelog.txt> [<changelog.md>]
#
# If the output path is not specified, it defaults to changelog.md in the same directory.
########################################################################################################################

INPUT=$1
OUTPUT=$2

if [ -z "$INPUT" ]; then
  echo "Usage: migrate-changelog.sh <changelog.txt> [<changelog.md>]"
  exit 1
fi
if ! [ -f "$INPUT" ]; then
  echo "ERROR: '$INPUT' is not a valid file"
  exit 1
fi

if [ -z "$OUTPUT" ]; then
  OUTPUT="$(dirname "$INPUT")/changelog.md"
fi

# Auto-detect the JIRA project key from the first issue reference in the file
# Handles both "    * KEY-123" and "    * [KEY-123]" formats
JIRA_KEY=$(grep -oP '^\s+\*\s+\[?\K[A-Z]+-' "$INPUT" | head -1 | sed 's/-$//')
if [ -z "$JIRA_KEY" ]; then
  echo "ERROR: Could not detect JIRA project key from issue entries in '$INPUT'"
  exit 1
fi
echo "Detected JIRA project key: $JIRA_KEY"

# Detect whether this is an ORM-style changelog (with "Changes in" prefix)
IS_ORM_STYLE=false
if grep -qP '^Changes in ' "$INPUT"; then
  IS_ORM_STYLE=true
fi

{
  echo "# Changelog"
  echo ""

  prev_line=""
  first_line=true
  skip_blanks=false

  while IFS= read -r line; do
    # Skip title underline (=== lines) and discard the buffered title line above it
    if [[ "$line" =~ ^=+$ ]]; then
      prev_line="__SKIP__"
      skip_blanks=true
      continue
    fi

    # Skip blank lines immediately following the title block
    if [[ "$skip_blanks" == true ]]; then
      if [[ -z "$line" ]]; then
        continue
      fi
      skip_blanks=false
    fi

    # Skip separator lines (--- lines under version headers)
    if [[ "$line" =~ ^-+$ ]]; then
      continue
    fi

    if [[ "$first_line" == true ]]; then
      first_line=false
      prev_line="$line"
      continue
    fi

    # Process the previously buffered line
    process_line="$prev_line"
    prev_line="$line"

    # Skip if the previous line was discarded (title block)
    if [[ "$process_line" == "__SKIP__" ]]; then
      continue
    fi

    # Version header: ORM style "Changes in X.Y.Z (date)"
    if [[ "$IS_ORM_STYLE" == true ]] && [[ "$process_line" =~ ^Changes\ in\ (.+) ]]; then
      echo "## ${BASH_REMATCH[1]}"
      continue
    fi

    # Version header line (non-ORM)
    if [[ "$process_line" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] && [[ "$process_line" =~ \( ]]; then
      echo "## $process_line"
      continue
    fi

    # JIRA version URL
    if [[ "$process_line" =~ ^https://hibernate\.atlassian\.net/projects/.+/versions/ ]]; then
      echo "[Full changelog]($process_line)"
      continue
    fi

    # Issue type header: "** Type" → "### Type"
    if [[ "$process_line" =~ ^\*\*\ (.+) ]]; then
      echo "### ${BASH_REMATCH[1]}"
      continue
    fi

    # Issue entry: "    * KEY-123 summary" → "* [KEY-123](browse-link) - summary"
    if [[ "$process_line" =~ ^[[:space:]]+\*[[:space:]]+($JIRA_KEY-[0-9]+)[[:space:]]+(.*) ]]; then
      local_key="${BASH_REMATCH[1]}"
      local_summary="${BASH_REMATCH[2]}"
      echo "* [${local_key}](https://hibernate.atlassian.net/browse/${local_key}) - $local_summary"
      continue
    fi

    # Issue entry (older format with brackets): "    * [KEY-123] - summary"
    if [[ "$process_line" =~ ^[[:space:]]+\*[[:space:]]+\[($JIRA_KEY-[0-9]+)\][[:space:]]*(.*) ]]; then
      local_key="${BASH_REMATCH[1]}"
      local_summary="${BASH_REMATCH[2]}"
      echo "* [${local_key}](https://hibernate.atlassian.net/browse/${local_key}) ${local_summary}"
      continue
    fi

    # Pass through everything else (blank lines, etc.)
    echo "$process_line"
  done < "$INPUT"

  # Process the last buffered line
  if [[ -n "$prev_line" ]] && [[ "$prev_line" != "__SKIP__" ]]; then
    echo "$prev_line"
  fi
} > "$OUTPUT"

echo "Migrated '$INPUT' -> '$OUTPUT'"
echo ""
echo "Next steps:"
echo "  1. Review the generated $OUTPUT"
echo "  2. Remove the old $INPUT"
echo "  3. Commit both changes"
