<#
.SYNOPSIS
	Store PC's uptime in a log file
.DESCRIPTION
    Ce script add a new line in a log file with:
	- Current timestamp
	- Uptime since last start of the PC
    If the file does not exist, create it with headers.
.NOTES
    Nom: LogUptimeData.ps1
    Auteur: PV
#>

# Variables
$OutputDirectory = "C:\T25147\"
$FilePrefix = "UptimeLog"
$DateFormat = "yyyy-MM-dd_HH-mm-ss"

# Create file name
$OutputFile = Join-Path -Path $OutputDirectory -ChildPath "$FilePrefix.log"

# Create directory if it does not exist
if (-not (Test-Path -Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    Write-Host "Created directory: $OutputDirectory"
}

try {
    # Retrieve current timestamp
    $CurrentTimestamp = Get-Date
    $FormattedTimestamp = $CurrentTimestamp.ToString($DateFormat)
    
    # Get elapsed time since system startup
    $BootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    $Uptime = $CurrentTimestamp - $BootTime
    
    # Format uptime
    $FormattedUptime = "{0} days, {1:D2}:{2:D2}:{3:D2}" -f $Uptime.Days, $Uptime.Hours, $Uptime.Minutes, $Uptime.Seconds
    $UptimeSeconds = $Uptime.TotalSeconds
    
    # Create row object with data
    $DataRow = [PSCustomObject]@{
        Timestamp = $FormattedTimestamp
        Date = $CurrentTimestamp.ToString("yyyy-MM-dd")
        Time = $CurrentTimestamp.ToString("HH:mm:ss")
        UptimeFormatted = $FormattedUptime
        UptimeDays = $Uptime.Days
        UptimeHours = $Uptime.Hours
        UptimeMinutes = $Uptime.Minutes
        UptimeSeconds = $Uptime.Seconds
        TotalUptimeSeconds = [math]::Round($UptimeSeconds, 2)
        BootTime = $BootTime.ToString($DateFormat)
    }
    
    # Check the log file already exists
    $FileExists = Test-Path -Path $OutputFile
    
    # Add line in log file
    if ($FileExists) {
        # Add line to existing file without header
        $DataRow | Export-Csv -Path $OutputFile -Append -NoTypeInformation -UseCulture -Encoding UTF8
        Write-Host "Data added to existing file: $OutputFile"
    } else {
        # Create new file with header
        $DataRow | Export-Csv -Path $OutputFile -NoTypeInformation -UseCulture -Encoding UTF8
        Write-Host "New file: $OutputFile"
    }
    
    # Display status
    Write-Host "Timestamp: $FormattedTimestamp"
    Write-Host "Uptime: $FormattedUptime"
    
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}