<#
.SYNOPSIS
    Create a Cm dust filt
.DESCRIPTION
	This script calls cmu executable to generate dust file.
.NOTES
    Auteur: PV
    Version: 1.0
	Hints: All configuration values are hard-coded into the script. 
#>

# Storage directory
$OutputDirectory = "C:\T25147\"
$ExecutablePath = "C:\Program Files\CodeMeter\Runtime\bin\cmu32.exe"
$ExecutableArgs = "--cmdust --file"
$FilePrefix = "CmDustFile"
$FileExtension = ".txt"

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

# Check executable exists
if (-not (Test-Path -Path $ExecutablePath)) {
    Write-Log "ERROR:Specified executable does not exist: $ExecutablePath" -Level "ERROR"
    exit 1
}

if (-not (Test-Path -Path $OutputDirectory)) {
	try {
		New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
		Write-Log "Output directory created: $OutputDirectory"
	} catch {
		Write-Log "ERROR: Cannot create output directory: $_" -Level "ERROR"
		exit 1
	}
}

# Create the directory if it does not exist
if (-not (Test-Path -Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force
}

# Timestamp
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Create output file name
$OutputFileName = "${FilePrefix}_${Timestamp}${FileExtension}"
$OutputFilePath = Join-Path -Path $OutputDirectory -ChildPath $OutputFileName

Write-Log "Starting execution: $ExecutablePath $ExecutableArgs `"$OutputFilePath`"" 

# Build a process to execute cmu.exe
$Process = New-Object System.Diagnostics.Process
$Process.StartInfo.FileName = "$ExecutablePath"
$Process.StartInfo.Arguments = "$ExecutableArgs `"$OutputFilePath`""
$Process.StartInfo.UseShellExecute = $false
$Process.StartInfo.RedirectStandardOutput = $true
$Process.StartInfo.RedirectStandardError = $true
$Process.StartInfo.CreateNoWindow = $false

[void]$Process.Start()
$Process.BeginOutputReadLine()
$Process.BeginErrorReadLine()
$Process.WaitForExit()

# Check output code
if ($Process.ExitCode -eq 0) {
    Write-Log "cmu.exe succeeded"
} else {
    Write-Log "cmu.exe failed with code $($Process.ExitCode))" -Level "ERROR"
    
    # Display errors
    $Error = $ErrorBuilder.ToString()
    if (-not [String]::IsNullOrEmpty($Error)) {
        Write-Log "cmu error: $Error" -Level "ERROR"
    }
}