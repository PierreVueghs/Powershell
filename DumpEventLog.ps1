# Storage directory
$BackupDirectory = "C:\T25147\"

# Log function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$TimeStamp] [$Level] $Message"
    
    if ($Level -eq "ERROR") {
        Write-Host $LogMessage -ForegroundColor Red
    } elseif ($Level -eq "WARNING") {
        Write-Host $LogMessage -ForegroundColor Yellow
    } else {
        Write-Host $LogMessage
    }
}

# Create the directory if it does not exist
if (-not (Test-Path -Path $BackupDirectory)) {
	try {
		New-Item -ItemType Directory -Path $BackupDirectory -Force
		Write-Log "Backup directory created: $BackupDirectory"
	}
	catch {
		Write-Log "ERROR: Cannot create backup directory: $_" -Level "ERROR"
		exit 1
	}
}

# Timestamp
$DateStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# File name with journal type and timestamp
Get-EventLog -LogName "Application" | Export-Csv -Path $BackupDirectory"EventLog_Application_$DateStamp.csv" -NoTypeInformation
Get-EventLog -LogName "System" | Export-Csv -Path $BackupDirectory"EventLog_System_$DateStamp.csv" -NoTypeInformation
