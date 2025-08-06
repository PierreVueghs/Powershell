<#
.SYNOPSIS
	Retrieve and store information about the memory usage
.DESCRIPTION
	This script collects detailed information about memory usage, and store them in a timestamped CSV.
.NOTES
    Auteur: PV
    Version: 1.0
#>

# ======= CONFIGURATION (to be updated) =======
$OutputDirectory = "C:\T25147\"
$FilePrefix = "MemoryUsage_"
$FileExtension = ".csv"
$TimestampFormat = "yyyy-MM-dd_HH-mm-ss"
$TopProcessCount = 30
$IncludeProcessDetails = $true
$CumulativeFileName = "MemoryUsage_Cumulative.csv"
$CumulativeFilePath = Join-Path -Path $OutputDirectory -ChildPath $CumulativeFileName
# ======= END OF CONFIGURATION =======

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

# Function to format size in MB/GB
function Format-MemorySize {
    param([double]$SizeInBytes)
    
    if ($SizeInBytes -ge 1GB) {
        return "$([Math]::Round($SizeInBytes / 1GB, 2)) GB"
    } else {
        return "$([Math]::Round($SizeInBytes / 1MB, 2)) MB"
    }
}

# Create output directory if it does not exist
if (-not (Test-Path -Path $OutputDirectory)) {
    try {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
        Write-Log "Output directory created: $OutputDirectory"
    } catch {
        Write-Log "ERROR: Cannot create output directory: $_" -Level "ERROR"
        exit 1
    }
}

# Generate timestamp
$Timestamp = Get-Date -Format $TimestampFormat

# Create output file name
$OutputFileName = "${FilePrefix}${Timestamp}${FileExtension}"
$OutputFilePath = Join-Path -Path $OutputDirectory -ChildPath $OutputFileName

Write-Log "Collecting information about memory usage..."

try {
    # Retrieve system information
    $OS = Get-CimInstance -ClassName Win32_OperatingSystem
    $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    
    # Compute memory consumption
    $PhysicalMemoryTotal = $ComputerSystem.TotalPhysicalMemory
    $PhysicalMemoryFree = $OS.FreePhysicalMemory * 1KB
    $PhysicalMemoryUsed = $PhysicalMemoryTotal - $PhysicalMemoryFree
    $PhysicalMemoryUsedPercent = [Math]::Round(($PhysicalMemoryUsed / $PhysicalMemoryTotal) * 100, 2)
    
    $VirtualMemoryTotal = $OS.TotalVirtualMemorySize * 1KB
    $VirtualMemoryFree = $OS.FreeVirtualMemory * 1KB
    $VirtualMemoryUsed = $VirtualMemoryTotal - $VirtualMemoryFree
    $VirtualMemoryUsedPercent = [Math]::Round(($VirtualMemoryUsed / $VirtualMemoryTotal) * 100, 2)
    
    # Retrieve information about most memory-consuming processes
    $TopProcesses = Get-Process | Sort-Object -Property WorkingSet -Descending | Select-Object -First $TopProcessCount
    
    # Create object to store memory information
    $MemoryInfo = [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        TotalPhysicalMemory = Format-MemorySize -SizeInBytes $PhysicalMemoryTotal
        TotalPhysicalMemoryBytes = $PhysicalMemoryTotal
        UsedPhysicalMemory = Format-MemorySize -SizeInBytes $PhysicalMemoryUsed
        UsedPhysicalMemoryBytes = $PhysicalMemoryUsed
        FreePhysicalMemory = Format-MemorySize -SizeInBytes $PhysicalMemoryFree
        FreePhysicalMemoryBytes = $PhysicalMemoryFree
        PhysicalMemoryUsedPercent = "$PhysicalMemoryUsedPercent%"
        TotalVirtualMemory = Format-MemorySize -SizeInBytes $VirtualMemoryTotal
        TotalVirtualMemoryBytes = $VirtualMemoryTotal
        UsedVirtualMemory = Format-MemorySize -SizeInBytes $VirtualMemoryUsed
        UsedVirtualMemoryBytes = $VirtualMemoryUsed
        FreeVirtualMemory = Format-MemorySize -SizeInBytes $VirtualMemoryFree
        FreeVirtualMemoryBytes = $VirtualMemoryFree
        VirtualMemoryUsedPercent = "$VirtualMemoryUsedPercent%"
    }
    
    # Add information about most memory-consuming processes
    if ($IncludeProcessDetails) {
        $ProcessDetails = @()
        foreach ($Process in $TopProcesses) {
            $ProcessInfo = [PSCustomObject]@{
                ProcessName = $Process.Name
                ProcessId = $Process.Id
                WorkingSet = Format-MemorySize -SizeInBytes $Process.WorkingSet64
                WorkingSetBytes = $Process.WorkingSet64
                PrivateMemory = Format-MemorySize -SizeInBytes $Process.PrivateMemorySize64
                PrivateMemoryBytes = $Process.PrivateMemorySize64
                VirtualMemory = Format-MemorySize -SizeInBytes $Process.VirtualMemorySize64
                VirtualMemoryBytes = $Process.VirtualMemorySize64
                CPUPercent = if ($Process.CPU) { [Math]::Round($Process.CPU, 2) } else { "N/A" }
                StartTime = if ($Process.StartTime) { $Process.StartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
                ThreadCount = $Process.Threads.Count
            }
            $ProcessDetails += $ProcessInfo
        }
    }
    
    # In case details on most memory-consuming processes are included, add them to CSV file
    if ($IncludeProcessDetails) {
        # Add details
        $ProcessDetails | Export-Csv -Path "$OutputFilePath.temp" -NoTypeInformation -Encoding UTF8
        Get-Content -Path "$OutputFilePath.temp" | Add-Content -Path $OutputFilePath
        Remove-Item -Path "$OutputFilePath.temp" -Force
    }
	
	# Export to the cumulative file
	if (Test-Path -Path $CumulativeFilePath) {
		# File already exists, append data without headers
		$MemoryInfo | Export-Csv -Path $CumulativeFilePath -NoTypeInformation -Encoding UTF8 -Append
	} else {
		# File doesn't exist, create it with headers
		$MemoryInfo | Export-Csv -Path $CumulativeFilePath -NoTypeInformation -Encoding UTF8
	}
    
    Write-Log "Information about memory stored in: $OutputFilePath"
    
    # Display synthesis
    Write-Host "`nMemory usage:" -ForegroundColor Cyan
    Write-Host "=============" -ForegroundColor Cyan
    Write-Host "Physical memory (total): $($MemoryInfo.TotalPhysicalMemory)"
    Write-Host "Physical memory (used): $($MemoryInfo.UsedPhysicalMemory) ($($MemoryInfo.PhysicalMemoryUsedPercent))"
    Write-Host "Physical memory (free): $($MemoryInfo.FreePhysicalMemory)"
    Write-Host "-----------------------------"
    Write-Host "Virtual memory (total): $($MemoryInfo.TotalVirtualMemory)"
    Write-Host "Virtual memory (used): $($MemoryInfo.UsedVirtualMemory) ($($MemoryInfo.VirtualMemoryUsedPercent))"
    Write-Host "Virtual memory (free): $($MemoryInfo.FreeVirtualMemory)"
    
    if ($IncludeProcessDetails) {
        Write-Host "`nTop $TopProcessCount most memory-consuming processes:" -ForegroundColor Cyan
        Write-Host "=======================================" -ForegroundColor Cyan
        $i = 1
        foreach ($Process in $ProcessDetails) {
            Write-Host "$i. $($Process.ProcessName) (PID: $($Process.ProcessId))"
            Write-Host "   Working memory: $($Process.WorkingSet)"
            Write-Host "   Private memory: $($Process.PrivateMemory)"
            $i++
        }
    }
    
} catch {
    Write-Log "ERROR while collecting memory information: $_" -Level "ERROR"
    exit 1
}

Write-Log "Operation successful"