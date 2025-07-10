<#
.SYNOPSIS
	Rotation script of CSV files
.DESCRIPTION
	Files contained in $BackupDirectory, with extension csv, are analyzed
	- Files from the last 7 days are kept
	- 1 file from the last 3 months is kept, per day and per type
	- Older files are removed
.NOTES
    Nom: RotateBackupFiles.ps1
    Auteur: PV
	Hints: type and timestamp are deduced from file name
#>

# Variables for customization
$BackupDirectory = "C:\T25147\"
$FileExtension = "csv"               # File extension 
$KeepAllDaysCount = 7                # Number of days when all files will be kept
$KeepOlderDaysCount = 90             # Number of days when one file (per type and per day) will be kept

# Date pattern
$DatePattern = "\d{4}-\d{2}-\d{2}"   # Format: yyyy-MM-dd

# Journalisation
$LogFile = Join-Path -Path $BackupDirectory -ChildPath "RotationLog_$(Get-Date -Format 'yyyy-MM-dd').log"
function Write-Log {
    param([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -FilePath $LogFile -Append
    Write-Host $Message
}

Write-Log "===== Starting rotation of backup files ====="
Write-Log "Directory: $BackupDirectory"
Write-Log "Extension: $FileExtension"
Write-Log "Full backup: $KeepAllDaysCount days"
Write-Log "Partial backup: $KeepOlderDaysCount days"

try {
    # Check directory exists
    if (-not (Test-Path -Path $BackupDirectory)) {
        Write-Log "ERROR: Backup directory does not exist: $BackupDirectory"
        exit 1
    }

    # Reference dates
    $Now = Get-Date
    $CutoffDateRecent = $Now.AddDays(-$KeepAllDaysCount)
    $CutoffDateOldest = $Now.AddDays(-$KeepOlderDaysCount)

    # List all CSV files in backup directory
    $AllFiles = Get-ChildItem -Path $BackupDirectory -Filter "*.$FileExtension" -File
    Write-Log "Total number of found .$FileExtension files: $($AllFiles.Count)"

    # For each file...
    $ProcessedFiles = @()
    foreach ($File in $AllFiles) {
        # ... retrieve its date from file name
        if ($File.Name -match $DatePattern) {
            $DatePart = $matches[0]
            $FileDate = [DateTime]::ParseExact($DatePart, "yyyy-MM-dd", $null)
            
            # ... retrieve its type from file name (part before first underscore, or the name without extension and date)
			if ($File.BaseName -match '^(.+)_\d{4}-\d{2}-\d{2}') {
				# ... retrieve everything before the date (preceded by an underscore)
				$FileType = $matches[1]
			} elseif ($File.BaseName -match '^([^_]+)_') {
			# Fallback on first version of the code
				$FileType = $matches[1]
			} else {
                # ... if no standard file name, then using file name without date as type
				$FileType = $File.BaseName -replace $DatePattern, '' -replace '_', ''
				if ([string]::IsNullOrWhiteSpace($FileType)) {
					$FileType = "Unknown"
				}
			}
            
            $ProcessedFiles += [PSCustomObject]@{
                File = $File
                FullPath = $File.FullName
                Type = $FileType
                Date = $FileDate
                DateString = $FileDate.ToString("yyyy-MM-dd")
            }
        } else {
            Write-Log "WARNING: Invalid format name, ignored: $($File.Name)"
        }
    }
    
    Write-Log "Files with valid date: $($ProcessedFiles.Count)"
    
    # Files to be removed
    $FilesToDelete = @()

    # 1. Remove all files older than the total keep-period
    $TooOldFiles = $ProcessedFiles | Where-Object { $_.Date -lt $CutoffDateOldest }
    foreach ($File in $TooOldFiles) {
        $FilesToDelete += $File
        Write-Log "Tagged for deletion (too old): $($File.File.Name)"
    }
    
    # 2. For files between $CutoffDateRecent and $CutoffDateOldest, keep only one file per day and per type
    $OlderFiles = $ProcessedFiles | Where-Object { $_.Date -lt $CutoffDateRecent -and $_.Date -ge $CutoffDateOldest }

    # Group per type and date
    $GroupedByTypeAndDate = $OlderFiles | Group-Object -Property Type, DateString
    
    foreach ($Group in $GroupedByTypeAndDate) {
        # Retrieve type and date per group name
        $GroupParts = $Group.Name -split ", "
        $GroupType = $GroupParts[0]
        $GroupDate = $GroupParts[1]
		
        # If more than 1 file for this date and type, only keep the most recent
        if ($Group.Group.Count -gt 1) {
			Write-Log "coco $Group.Group.Count"
            $FilesToKeep = $Group.Group | Sort-Object -Property File.LastWriteTime -Descending | Select-Object -First 1
            $FilesToRemove = $Group.Group | Where-Object { $_.FullPath -ne $FilesToKeep.FullPath }
            
            foreach ($File in $FilesToRemove) {
                $FilesToDelete += $File
                Write-Log "Tagged for deletion (one file kept per day/type): $($File.File.Name)"
            }
        }
    }
    
    # Remove all tagged files
    $DeletedCount = 0
    foreach ($File in $FilesToDelete) {
        try {
            Remove-Item -Path $File.FullPath -Force
            $DeletedCount++
            Write-Log "Removed: $($File.File.Name)"
        } catch {
            Write-Log "ERROR: Cannot remove file $($File.File.Name): $_"
        }
    }
    
    Write-Log "Rotation ended. $DeletedCount deleted files."
    
    # Display current disk space
    $Drive = (Get-Item $BackupDirectory).PSDrive.Name
    $DiskSpace = Get-PSDrive -Name $Drive
    Write-Log "Available disk space on ${Drive}: $([Math]::Round($DiskSpace.Free / 1GB, 2)) GB / $([Math]::Round($DiskSpace.Used / 1GB + $DiskSpace.Free / 1GB, 2)) GB"
    
} catch {
    Write-Log "CRITICAL ERROR: $_"
}

Write-Log "===== Rotation of backup files ended ====="