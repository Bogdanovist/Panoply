#!/bin/bash
# gws_backup.sh — Download and convert Google Drive files via gws CLI
# Usage: bash gws_backup.sh <output_dir> [--scope personal|shared|all] [--drive-id <id>]
#
# Requires: gws CLI installed and authenticated (gws auth login)

set -euo pipefail

OUTPUT_DIR="${1:?Usage: gws_backup.sh <output_dir> [--scope personal|shared|all] [--drive-id <id>]}"
SCOPE="personal"
DRIVE_ID=""

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    --drive-id) DRIVE_ID="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

# Build the query based on scope
case "$SCOPE" in
  personal)
    QUERY="'me' in owners and trashed = false"
    EXTRA_PARAMS=""
    ;;
  shared)
    if [ -z "$DRIVE_ID" ]; then
      echo "Error: --drive-id required for shared scope"
      exit 1
    fi
    QUERY="'${DRIVE_ID}' in parents and trashed = false"
    EXTRA_PARAMS=', "includeItemsFromAllDrives": true, "supportsAllDrives": true, "corpora": "allDrives"'
    ;;
  all)
    QUERY="trashed = false"
    EXTRA_PARAMS=', "includeItemsFromAllDrives": true, "supportsAllDrives": true, "corpora": "allDrives"'
    ;;
  *) echo "Invalid scope: $SCOPE (use personal, shared, or all)"; exit 1 ;;
esac

echo "=== GWS Drive Backup ==="
echo "Output: $OUTPUT_DIR"
echo "Scope: $SCOPE"
echo ""

# List all files
FILES_JSON=$(gws drive files list --params "{\"q\": \"${QUERY}\", \"pageSize\": 1000, \"fields\": \"files(id,name,mimeType,parents)\"${EXTRA_PARAMS}}" 2>/dev/null)

TOTAL=$(echo "$FILES_JSON" | jq '.files | length')
echo "Found $TOTAL files"
echo ""

# Process each file
echo "$FILES_JSON" | jq -c '.files[]' | while IFS= read -r file; do
  ID=$(echo "$file" | jq -r '.id')
  NAME=$(echo "$file" | jq -r '.name')
  MIME=$(echo "$file" | jq -r '.mimeType')

  # Sanitise filename (replace problematic chars)
  SAFE_NAME=$(echo "$NAME" | sed 's/[/:*?"<>|]/_/g' | sed 's/ /_/g' | sed 's/—/-/g')

  case "$MIME" in
    application/vnd.google-apps.document)
      echo "DOC → MD: $NAME"
      cd "$OUTPUT_DIR"
      gws drive files export --params "{\"fileId\": \"$ID\", \"mimeType\": \"text/markdown\"}" >/dev/null 2>&1
      [ -f download.bin ] && mv download.bin "${SAFE_NAME}.md"
      ;;

    application/vnd.google-apps.spreadsheet)
      echo "SHEET → CSV+XLSX: $NAME"
      SHEET_DIR="$OUTPUT_DIR/${SAFE_NAME}"
      mkdir -p "$SHEET_DIR"

      # Export as xlsx
      cd "$OUTPUT_DIR"
      gws drive files export --params "{\"fileId\": \"$ID\", \"mimeType\": \"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\"}" >/dev/null 2>&1
      local_ext=$(ls -t download.* 2>/dev/null | head -1)
      [ -n "$local_ext" ] && mv "$local_ext" "${SHEET_DIR}/${SAFE_NAME}.xlsx"

      # Export each tab as CSV
      TABS=$(gws sheets spreadsheets get --params "{\"spreadsheetId\": \"$ID\"}" 2>/dev/null | jq -r '.sheets[].properties.title' 2>/dev/null)
      if [ -n "$TABS" ]; then
        echo "$TABS" | while IFS= read -r tab; do
          SAFE_TAB=$(echo "$tab" | sed 's/[/:*?"<>|]/_/g')
          gws sheets spreadsheets values get --params "{\"spreadsheetId\": \"$ID\", \"range\": \"${tab}\"}" 2>/dev/null | jq -r '.values[] | @csv' > "${SHEET_DIR}/${SAFE_TAB}.csv" 2>/dev/null
          echo "  tab: $tab → ${SAFE_TAB}.csv"
        done
      fi
      ;;

    application/vnd.google-apps.presentation)
      echo "SLIDES → PPTX: $NAME"
      cd "$OUTPUT_DIR"
      gws drive files export --params "{\"fileId\": \"$ID\", \"mimeType\": \"application/vnd.openxmlformats-officedocument.presentationml.presentation\"}" >/dev/null 2>&1
      local_ext=$(ls -t download.* 2>/dev/null | head -1)
      [ -n "$local_ext" ] && mv "$local_ext" "${SAFE_NAME}.pptx"
      ;;

    application/vnd.google-apps.folder)
      echo "FOLDER: $NAME (skipping — structure is flat)"
      ;;

    application/vnd.google-apps.form)
      echo "FORM: $NAME (skipping — cannot export)"
      ;;

    *)
      echo "FILE: $NAME ($MIME)"
      cd "$OUTPUT_DIR"
      gws drive files get --params "{\"fileId\": \"$ID\", \"alt\": \"media\"}" >/dev/null 2>&1
      local_ext=$(ls -t download.* 2>/dev/null | head -1)
      if [ -n "$local_ext" ]; then
        # Preserve original extension if present
        if echo "$NAME" | grep -q '\.'; then
          mv "$local_ext" "${SAFE_NAME}"
        else
          EXT="${local_ext##*.}"
          mv "$local_ext" "${SAFE_NAME}.${EXT}"
        fi
      fi
      ;;
  esac
done

echo ""
echo "=== Backup complete ==="
echo "Files saved to: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR" | tail -n +2 | wc -l | tr -d ' '
echo " items in output directory"
