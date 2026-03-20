# How to use PhotoOrg

## Quick start
1. Download PhotoOrg.exe from the Releases page
2. Double click to run — no installation needed
3. Select your source folder (where your photos are)
4. Select your output folder (where sorted photos will go)
5. Click Start Organising

## Options explained

### Detect and move duplicate files
Scans all sorted files for exact duplicates using MD5 hashing.
Duplicates are moved to a Duplicates_Review folder.
Nothing is ever deleted automatically.

### Include hidden files
Processes files and folders that are marked as hidden on Windows.
Useful for photos imported from phones that hide system folders.

### Open output folder when finished
Automatically opens the Sorted folder in Windows Explorer
when organising is complete.

## Output structure
```
OutputFolder/
├── Sorted/
│   ├── 2019/
│   │   ├── 01-Jan/
│   │   └── 08-Aug/
│   ├── 2022/
│   │   └── 06-Jun/
│   └── 2024/
│       └── 12-Dec/
└── Duplicates_Review/
    └── (duplicates moved here for manual review)
```

## Supported file types
Photos: JPG JPEG HEIC HEIF PNG GIF BMP TIFF TIF WEBP RAW
Videos: MP4 MOV AVI MKV 3GP WMV MPG MPEG VOB M4V FLV

## Tips
- Always select an empty folder as your output destination
- Review the Duplicates_Review folder before deleting anything
- The activity log shows exactly what happened to each file
- Run the app again on the same source folder safely — 
  already sorted files will not be duplicated
```

Save with **Command + S**.

---

## Part 3 — Monetization Preparation

You do not need to charge anything now. Build reputation first, then layer in paid features later. Here is the roadmap.

### Phase 1 — Build reputation now (free)

Post your project in these places this week:

| Where | What to post |
|---|---|
| reddit.com/r/windows | Short post with screenshot and download link |
| reddit.com/r/software | Same post |
| reddit.com/r/DataHoarder | Mention the duplicate detection feature |
| alternativeto.net | Add PhotoOrg as an alternative to other photo organisers |
| fosshub.com | Submit as a free open source tool |

---

### Phase 2 — Add a Pro version later (optional)

Keep the current app free forever. Add a Pro tier with premium features:
```
Free (always)          Pro ($9 one-time)
─────────────────────────────────────────
Sort by year/month     Custom folder patterns
Basic duplicates       AI face grouping
Standard file types    RAW camera formats
                       Cloud backup option
                       Priority email support