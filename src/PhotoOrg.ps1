# PhotoOrg_Auto.ps1 - Fully Automatic Photo and Video Organiser v3

$ExifTool  = "C:\PhotoOrg\exiftool.exe"
$InboxDir  = "C:\PhotoOrg\Inbox"
$SortedDir = "C:\PhotoOrg\Sorted"
$DupesDir  = "C:\PhotoOrg\Duplicates_Review"
$LogFile   = "C:\PhotoOrg\run_log.txt"

$FileTypes = @("jpg","jpeg","heic","heif","png","gif","bmp","tiff","tif","webp","raw","cr2","nef","arw","dng","mp4","mov","avi","mkv","3gp","wmv","mpg","mpeg","vob","m4v","flv","ts","mts","m2ts","asf")

$monthNames = @("","01-Jan","02-Feb","03-Mar","04-Apr","05-May","06-Jun","07-Jul","08-Aug","09-Sep","10-Oct","11-Nov","12-Dec")

function WriteLog {
    param($msg, $col)
    if (-not $col) { $col = "White" }
    $ts = Get-Date -Format "HH:mm:ss"
    $line = "[" + $ts + "] " + $msg
    Write-Host $line -ForegroundColor $col
    Add-Content -Path $LogFile -Value $line
}

function WriteSection {
    param($title)
    $bar = "======================================================="
    Write-Host ""
    Write-Host $bar -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host $bar -ForegroundColor Cyan
    Write-Host ""
    Add-Content -Path $LogFile -Value ""
    Add-Content -Path $LogFile -Value $bar
    Add-Content -Path $LogFile -Value "  $title"
    Add-Content -Path $LogFile -Value $bar
}

Clear-Host
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host "   PhotoOrg Auto v3 - Automatic Organiser        " -ForegroundColor Cyan
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host ""

Set-Content -Path $LogFile -Value ("PhotoOrg Auto v3 - Started " + (Get-Date))

# --------------------------------------------------
# PHASE 1 - CHECKS
# --------------------------------------------------
WriteSection "Phase 1 of 5 - Pre-flight checks"

if (-not (Test-Path $ExifTool)) {
    Write-Host "  ERROR: exiftool.exe not found at C:\PhotoOrg\exiftool.exe" -ForegroundColor Red
    Write-Host "  1. Go to https://exiftool.org/" -ForegroundColor Yellow
    Write-Host "  2. Download Windows Executable" -ForegroundColor Yellow
    Write-Host "  3. Unzip and rename to exiftool.exe" -ForegroundColor Yellow
    Write-Host "  4. Copy to C:\PhotoOrg\" -ForegroundColor Yellow
    Read-Host "  Press Enter to exit"
    exit 1
}
WriteLog "ExifTool found OK" "Green"

if (-not (Test-Path $InboxDir)) {
    Write-Host "  ERROR: Inbox folder not found at C:\PhotoOrg\Inbox" -ForegroundColor Red
    Read-Host "  Press Enter to exit"
    exit 1
}
WriteLog "Inbox folder found OK" "Green"

if (-not (Test-Path $SortedDir)) {
    New-Item -ItemType Directory -Path $SortedDir -Force | Out-Null
    WriteLog "Created Sorted folder" "Green"
} else {
    WriteLog "Sorted folder exists OK" "Gray"
}

if (-not (Test-Path $DupesDir)) {
    New-Item -ItemType Directory -Path $DupesDir -Force | Out-Null
    WriteLog "Created Duplicates_Review folder" "Green"
} else {
    WriteLog "Duplicates_Review folder exists OK" "Gray"
}

WriteLog "Counting all media files in Inbox including hidden files..." "Yellow"

$allInboxFiles = Get-ChildItem -Path $InboxDir -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
    (-not $_.PSIsContainer) -and ($FileTypes -contains $_.Extension.TrimStart(".").ToLower())
}

$totalFiles = $allInboxFiles.Count
WriteLog ("Found " + $totalFiles + " media files in Inbox") "Cyan"

$typeGroups = $allInboxFiles | Group-Object { $_.Extension.TrimStart(".").ToLower() } | Sort-Object Count -Descending
Write-Host ""
Write-Host "  File types found in Inbox:" -ForegroundColor Gray
foreach ($tg in $typeGroups) {
    Write-Host ("    ." + $tg.Name + " : " + $tg.Count + " files") -ForegroundColor Gray
}
Write-Host ""

if ($totalFiles -eq 0) {
    Write-Host "  No media files found in Inbox. Please check your files are there." -ForegroundColor Red
    Read-Host "  Press Enter to exit"
    exit 1
}

Write-Host ("  Ready to process " + $totalFiles + " files") -ForegroundColor Cyan
Write-Host "  Source  : C:\PhotoOrg\Inbox" -ForegroundColor Gray
Write-Host "  Output  : C:\PhotoOrg\Sorted" -ForegroundColor Gray
Write-Host "  Dupes   : C:\PhotoOrg\Duplicates_Review" -ForegroundColor Gray
Write-Host ""
$confirm = Read-Host "  Type YES to start, or anything else to cancel"

if ($confirm -ne "YES") {
    WriteLog "Cancelled by user." "Gray"
    Read-Host "Press Enter to exit"
    exit 0
}

# --------------------------------------------------
# PHASE 2 - UNHIDE FILES
# --------------------------------------------------
WriteSection "Phase 2 of 5 - Removing hidden attributes"

WriteLog "Removing hidden flag from all files in Inbox..." "Yellow"

Get-ChildItem -Path $InboxDir -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        if ($_.Attributes -band [System.IO.FileAttributes]::Hidden) {
            $_.Attributes = $_.Attributes -bxor [System.IO.FileAttributes]::Hidden
        }
    } catch { }
}

WriteLog "Hidden attributes removed." "Green"

# --------------------------------------------------
# PHASE 3 - SORT BY DATE
# --------------------------------------------------
WriteSection "Phase 3 of 5 - Sorting files into Year and Month folders"
WriteLog ("Sorting " + $totalFiles + " files...") "Yellow"
Write-Host ""

$sortedCount = 0
$noExifCount = 0
$errorCount  = 0
$i = 0

foreach ($file in $allInboxFiles) {
    $i++
    $pct = [math]::Round(($i / $totalFiles) * 100)
    Write-Progress -Activity "Sorting files by date..." -Status ("$i of $totalFiles - " + $file.Name) -PercentComplete $pct

    try {
        $exifDate = & $ExifTool -DateTimeOriginal -d "%Y:%m" -s3 $file.FullName 2>$null

        if (-not $exifDate -or $exifDate -notmatch "^\d{4}:\d{2}$") {
            $exifDate = & $ExifTool -CreateDate -d "%Y:%m" -s3 $file.FullName 2>$null
        }

        if (-not $exifDate -or $exifDate -notmatch "^\d{4}:\d{2}$") {
            $exifDate = & $ExifTool -MediaCreateDate -d "%Y:%m" -s3 $file.FullName 2>$null
        }

        if ($exifDate -and $exifDate -match "^(\d{4}):(\d{2})$") {
            $year     = $Matches[1]
            $monthNum = [int]$Matches[2]
            if ([int]$year -lt 1990 -or [int]$year -gt 2030) {
                $year     = $file.LastWriteTime.Year.ToString()
                $monthNum = $file.LastWriteTime.Month
                $destFolder = $SortedDir + "\" + $year + "\" + $monthNames[$monthNum] + "_NoEXIF"
                $noExifCount++
            } else {
                $destFolder = $SortedDir + "\" + $year + "\" + $monthNames[$monthNum]
            }
        } else {
            $year     = $file.LastWriteTime.Year.ToString()
            $monthNum = $file.LastWriteTime.Month
            $destFolder = $SortedDir + "\" + $year + "\" + $monthNames[$monthNum] + "_NoEXIF"
            $noExifCount++
        }

        if (-not (Test-Path $destFolder)) {
            New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
        }

        $destFile = Join-Path $destFolder $file.Name
        if (Test-Path $destFile) {
            $nameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $ext       = $file.Extension
            $stamp     = Get-Date -Format "HHmmssff"
            $destFile  = Join-Path $destFolder ($nameNoExt + "_" + $stamp + $ext)
        }

        Move-Item -Path $file.FullName -Destination $destFile -Force
        $sortedCount++

    } catch {
        WriteLog ("ERROR sorting " + $file.Name + ": " + $_) "Red"
        $errorCount++
    }
}

Write-Progress -Activity "Sorting files by date..." -Completed
WriteLog ("Sorting done. Sorted: " + $sortedCount + " | No EXIF: " + $noExifCount + " | Errors: " + $errorCount) "Green"

# --------------------------------------------------
# PHASE 4 - DUPLICATE DETECTION
# --------------------------------------------------
WriteSection "Phase 4 of 5 - Finding duplicate files"
WriteLog "Scanning Sorted folder for duplicates..." "Yellow"
Write-Host ""

$allSorted = Get-ChildItem -Path $SortedDir -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
    (-not $_.PSIsContainer) -and ($FileTypes -contains $_.Extension.TrimStart(".").ToLower())
}

$sizeGroups     = $allSorted | Group-Object -Property Length | Where-Object { $_.Count -gt 1 }
$candidateFiles = $sizeGroups | ForEach-Object { $_.Group }
$candidateCount = ($candidateFiles | Measure-Object).Count

WriteLog ("Checking " + $candidateCount + " files with matching sizes...") "Yellow"

$dupeCount = 0
$hashTable = @{}
$j = 0

foreach ($file in $candidateFiles) {
    $j++
    $pct2 = [math]::Round(($j / [math]::Max($candidateCount, 1)) * 100)
    Write-Progress -Activity "Checking for duplicates..." -Status ("$j of $candidateCount - " + $file.Name) -PercentComplete $pct2

    try {
        $hash = (Get-FileHash -Path $file.FullName -Algorithm MD5).Hash

        if ($hashTable.ContainsKey($hash)) {
            $dupeDest = Join-Path $DupesDir $file.Name
            if (Test-Path $dupeDest) {
                $nameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                $ext       = $file.Extension
                $stamp     = Get-Date -Format "HHmmssff"
                $dupeDest  = Join-Path $DupesDir ($nameNoExt + "_" + $stamp + $ext)
            }
            Move-Item -Path $file.FullName -Destination $dupeDest -Force
            WriteLog ("DUPE moved: " + $file.Name) "DarkYellow"
            $dupeCount++
        } else {
            $hashTable[$hash] = $file.FullName
        }
    } catch {
        WriteLog ("ERROR hashing " + $file.Name + ": " + $_) "Red"
    }
}

Write-Progress -Activity "Checking for duplicates..." -Completed
WriteLog ("Duplicate detection done. Duplicates moved: " + $dupeCount) "Green"

# --------------------------------------------------
# PHASE 5 - CLEAN UP EMPTY FOLDERS
# --------------------------------------------------
WriteSection "Phase 5 of 5 - Cleaning up empty folders"

Get-ChildItem -Path $InboxDir -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.PSIsContainer } |
    Sort-Object -Property FullName -Descending |
    ForEach-Object {
        $kids = Get-ChildItem -Path $_.FullName -Force -ErrorAction SilentlyContinue
        if (-not $kids) {
            Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
        }
    }

WriteLog "Empty folders cleaned up." "Green"

$remainingFiles = Get-ChildItem -Path $InboxDir -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
$remainingCount = ($remainingFiles | Measure-Object).Count

# --------------------------------------------------
# FINAL SUMMARY
# --------------------------------------------------
$finalSorted = (Get-ChildItem -Path $SortedDir -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }).Count
$finalDupes  = (Get-ChildItem -Path $DupesDir  -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }).Count
$yearFolders = (Get-ChildItem -Path $SortedDir -Directory -ErrorAction SilentlyContinue).Count

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Green
Write-Host "   ALL DONE - Summary                            " -ForegroundColor Green
Write-Host "  ================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("  Total files processed    : " + $totalFiles) -ForegroundColor White
Write-Host ("  Files sorted by date     : " + $sortedCount) -ForegroundColor White
Write-Host ("  Files with no EXIF       : " + $noExifCount) -ForegroundColor Yellow
Write-Host ("  Duplicates moved         : " + $dupeCount) -ForegroundColor Yellow
Write-Host ("  Year folders created     : " + $yearFolders) -ForegroundColor White
Write-Host ("  Files still in Inbox     : " + $remainingCount) -ForegroundColor Yellow
Write-Host ("  Errors                   : " + $errorCount) -ForegroundColor White
Write-Host ""
Write-Host "  Organised photos  : C:\PhotoOrg\Sorted" -ForegroundColor Cyan
Write-Host "  Duplicates folder : C:\PhotoOrg\Duplicates_Review" -ForegroundColor Cyan
Write-Host "  Full log file     : C:\PhotoOrg\run_log.txt" -ForegroundColor Cyan
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Open Sorted folder and check year folders look correct" -ForegroundColor White
Write-Host "  2. Open Duplicates_Review and delete confirmed duplicates" -ForegroundColor White
Write-Host "  3. Once happy delete the Inbox folder to free up space" -ForegroundColor White
Write-Host "  4. Copy Sorted folder back to your HDD using FreeFileSync" -ForegroundColor White
Write-Host ""

WriteLog ("Script finished. Sorted: " + $sortedCount + " | Dupes: " + $dupeCount + " | Remaining: " + $remainingCount + " | Errors: " + $errorCount) "Green"
Read-Host "  Press Enter to close"
