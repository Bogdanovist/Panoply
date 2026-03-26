---
name: gws-drive-backup
description: Download and back up Google Drive files locally via the gws CLI with format conversion and AI-readable output. Google Docs to Markdown (with image extraction), Google Sheets to CSV per tab plus XLSX, Google Slides to PPTX. Also converts downloaded .docx to Markdown and .xlsx to CSV per tab for AI readability. Supports personal Drive, shared drives, and folder structures. Use when (1) user asks to back up, download, copy, sync, or mirror Google Drive files locally, (2) user asks to export or convert Google Docs, Sheets, Slides, .docx, or .xlsx to AI-readable formats, (3) user wants offline access to Drive content, (4) user mentions drive backup, download from Drive, export Drive, or copy Drive files.
---

# GWS Drive Backup

## Prerequisites

- `gws` CLI installed and authenticated (`gws auth login`)
- `jq` on PATH
- Python 3 on PATH (standard library only for `extract_images.py`)
- `pandoc` on PATH (for .docx → .md conversion). Install: `brew install pandoc`
- `openpyxl` Python package (for .xlsx → .csv conversion). Install: `pip3 install openpyxl`

Verify: `gws drive files list --params '{"pageSize": 1}'`

## Two-phase workflow

### Phase 1 — Download from Drive (`gws_backup.sh`)

Downloads files from Google Drive with Google-native format conversion:

```bash
bash <skill_dir>/scripts/gws_backup.sh <output_dir> [--scope personal|shared|all] [--drive-id <id>]
```

| Source type | Downloaded as |
|------------|---------------|
| Google Docs | `.md` (with base64 images extracted to `images/` + `.docx` if images found) |
| Google Sheets | subfolder: `.csv` per tab + `.xlsx` |
| Google Slides | `.pptx` |
| Google Forms | skipped (not exportable) |
| Other files | as-is (PDF, DOCX, XLSX, ZIP, etc.) |

### Phase 2 — Convert local files (`convert_local.py`)

Converts downloaded binary files to AI-readable formats:

```bash
python3 <skill_dir>/scripts/convert_local.py <directory>
```

| Source type | Converted to |
|------------|-------------|
| `.docx` | `.md` via pandoc (images extracted to `images/` subfolder) |
| `.xlsx` | subfolder with `.csv` per sheet tab via openpyxl |

The script is idempotent — it skips files that already have conversions (e.g. a `.docx` where a `.md` with the same basename exists).

**Run Phase 2 after Phase 1** to ensure all content is available as plaintext for AI processing.

## Image handling

### Google Docs (Phase 1)

Google's markdown export embeds images as base64 data URIs. The `extract_images.py` script decodes each to a separate file in `images/` and rewrites the markdown with local paths:

```bash
python3 <skill_dir>/scripts/extract_images.py <markdown_file>
```

Before: `[image1]: <data:image/png;base64,iVBOR...>` (huge base64 blob)
After: `[image1]: images/image1.png` (clean local reference)

If images are found, the backup script also exports a `.docx` copy as a backup.

### Uploaded .docx files (Phase 2)

Pandoc extracts embedded images to `images/media/` and references them in the markdown output automatically.

## Manual export commands

### List files

```bash
# Personal
gws drive files list --params '{"q": "'\''me'\'' in owners and trashed = false", "pageSize": 100, "fields": "files(id,name,mimeType,parents)"}'

# Shared drives
gws drive files list --params '{"q": "trashed = false", "includeItemsFromAllDrives": true, "supportsAllDrives": true, "corpora": "allDrives", "pageSize": 100}'

# List shared drives
gws drive drives list --params '{"pageSize": 50}'
```

### Google Docs → Markdown

```bash
gws drive files export --params '{"fileId": "ID", "mimeType": "text/markdown"}'
mv download.bin "filename.md"
```

### Google Sheets → CSV + XLSX

```bash
gws drive files export --params '{"fileId": "ID", "mimeType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}'
mv download.xml "sheet.xlsx"

gws sheets spreadsheets get --params '{"spreadsheetId": "ID"}' | jq -r '.sheets[].properties.title'

gws sheets spreadsheets values get --params '{"spreadsheetId": "ID", "range": "TAB"}' | jq -r '.values[] | @csv' > "tab.csv"
```

### Google Slides → PPTX

```bash
gws drive files export --params '{"fileId": "ID", "mimeType": "application/vnd.openxmlformats-officedocument.presentationml.presentation"}'
mv download.xml "slides.pptx"
```

### Binary files

```bash
gws drive files get --params '{"fileId": "ID", "alt": "media"}'
mv download.bin "filename.ext"
```

## gws export behaviour

- `export` saves to `download.bin` (text) or `download.xml` (office formats) in CWD
- Each export **overwrites** the previous — rename immediately
- Shared drives require: `includeItemsFromAllDrives`, `supportsAllDrives`, `corpora: "allDrives"`
- Paginate via `nextPageToken` / `pageToken`
- All operations are **read-only** — no Drive data is modified
