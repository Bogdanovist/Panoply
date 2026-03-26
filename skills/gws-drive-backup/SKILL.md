---
name: gws-drive-backup
description: Download and back up Google Drive files locally via the gws CLI with automatic format conversion. Google Docs to Markdown, Google Sheets to CSV per tab plus XLSX, Google Slides to PPTX, all other files downloaded as-is. Supports personal Drive, shared drives, and folder structures. Use when (1) user asks to back up, download, copy, or sync Google Drive files locally, (2) user asks to export Google Docs/Sheets/Slides to local formats, (3) user wants a local mirror of Drive content for offline access or processing, (4) user mentions gws backup, drive backup, download from Drive, export Drive, or copy Drive files.
---

# GWS Drive Backup

## Prerequisites

Verify gws CLI is installed and authenticated:

```bash
gws drive files list --params '{"pageSize": 1}'
```

Requires `jq` on PATH for JSON processing.

## Quick start — backup script

Run `scripts/gws_backup.sh` to automate the full download with format conversions:

```bash
bash <skill_dir>/scripts/gws_backup.sh <output_dir> [--scope personal|shared|all] [--drive-id <id>]
```

```bash
# Personal Drive
bash <skill_dir>/scripts/gws_backup.sh ./backup/my_drive

# Specific shared drive
bash <skill_dir>/scripts/gws_backup.sh ./backup/shared --scope shared --drive-id 0ANNP52NXM_4zUk9PVA

# Everything
bash <skill_dir>/scripts/gws_backup.sh ./backup/all --scope all
```

## Format conversion rules

| Source type | Output |
|------------|--------|
| Google Docs (`application/vnd.google-apps.document`) | `.md` (Markdown) |
| Google Sheets (`application/vnd.google-apps.spreadsheet`) | Subdirectory with `.csv` per tab + `.xlsx` full workbook |
| Google Slides (`application/vnd.google-apps.presentation`) | `.pptx` |
| Google Forms | Skipped (not exportable via API) |
| All other files (PDF, DOCX, XLSX, ZIP, etc.) | Downloaded as-is |

## Manual workflow

### List files

```bash
# Personal files
gws drive files list --params '{"q": "'\''me'\'' in owners and trashed = false", "pageSize": 100, "fields": "files(id,name,mimeType,parents)"}'

# Shared drives (add these three params)
gws drive files list --params '{"q": "trashed = false", "includeItemsFromAllDrives": true, "supportsAllDrives": true, "corpora": "allDrives", "pageSize": 100}'

# List available shared drives
gws drive drives list --params '{"pageSize": 50}'
```

### Export Google Docs → Markdown

```bash
gws drive files export --params '{"fileId": "ID", "mimeType": "text/markdown"}'
mv download.bin "filename.md"
```

### Export Google Sheets → CSV per tab + XLSX

```bash
# Full workbook as XLSX
gws drive files export --params '{"fileId": "ID", "mimeType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}'
mv download.xml "sheetname.xlsx"

# Get tab names
gws sheets spreadsheets get --params '{"spreadsheetId": "ID"}' | jq -r '.sheets[].properties.title'

# Export one tab as CSV
gws sheets spreadsheets values get --params '{"spreadsheetId": "ID", "range": "TAB_NAME"}' | jq -r '.values[] | @csv' > "tab.csv"
```

### Export Google Slides → PPTX

```bash
gws drive files export --params '{"fileId": "ID", "mimeType": "application/vnd.openxmlformats-officedocument.presentationml.presentation"}'
mv download.xml "presentation.pptx"
```

### Download binary files

```bash
gws drive files get --params '{"fileId": "ID", "alt": "media"}'
mv download.bin "original_filename.ext"
```

## Key gws behaviours

- `export` saves to `download.bin` (text formats) or `download.xml` (office formats) in CWD
- Each export **overwrites** the previous file — rename immediately after each one
- Shared drive queries require all three: `includeItemsFromAllDrives`, `supportsAllDrives`, `corpora: "allDrives"`
- For pagination, check `nextPageToken` in responses and pass as `pageToken`
- All operations are **read-only** — no Drive data is modified

## Safety

This skill uses only read-only gws operations (`list`, `get`, `export`, `values get`). The gws-write-guard hook (if installed) will not block any commands in this workflow.
