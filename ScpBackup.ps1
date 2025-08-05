<#
.SYNOPSIS
    Compress and upload files via SCP to remote machine
.DESCRIPTION
	This script compresses a local folder and uploads it to a remote server via SCP.
.NOTES
    Auteur: PV
    Version: 1.0
	Hints: All configuration values are hard-coded into the script. I also needed to create
		   a RSA key, and copy public key to the remote machine I wanted to target
#>

# ======= CONFIGURATION (to be updated) =======
# Path to the directory for backup
$SourcePath = "C:\T25147\"

# Configuration of remote (Linux) server
$LinuxServer = "vst-gandalf.euresys.com"           # Ip addres or hostname of the remote (Linux) server
$LinuxUsername = "chinesepcsbackup"           # User name
$LinuxRemotePath = "/home/chinesepcsbackup/temp"  # Absolute path to the server, where archive will be sent

# Options
$DeleteLocalArchiveAfterTransfer = $true # Delete local archive after upload
$IncludeTimestampInName = $true         # Add a timestamp in the name of the archive
$SSHPort = 22                           # Port SSH (usually 22)

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

# Check the source path exists
if (-not (Test-Path -Path $SourcePath)) {
    Write-Log "Source path does not exist: $SourcePath" -Level "ERROR"
    exit 1
}

# Create a name for the archive
$SourceFolderName = $env:userdomain

if ($IncludeTimestampInName) {
    $DateStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $ArchiveName = "${SourceFolderName}_${DateStamp}"
} else {
    $ArchiveName = $SourceFolderName
}

Write-Log "Starting working on: $SourcePath"
Write-Log "Target server: $LinuxServer, Path: $LinuxRemotePath"

try {
    # Directory compression
    $TempPath = [System.IO.Path]::GetTempPath()
    $ArchivePath = Join-Path -Path $TempPath -ChildPath "$ArchiveName.zip"
    
    Write-Log "Compression of directory: $SourcePath -> $ArchivePath"
    
    # Check if source directory is empty
    $HasContent = (Get-ChildItem -Path $SourcePath -Force | Measure-Object).Count -gt 0
    if (-not $HasContent) {
        Write-Log "Source directory is empty!" -Level "WARNING"
    }
    
    # Compression with PowerShell
    Compress-Archive -Path "$SourcePath\*" -DestinationPath $ArchivePath -CompressionLevel Optimal -Force
    
    if (Test-Path -Path $ArchivePath) {
        $ArchiveSize = (Get-Item -Path $ArchivePath).Length / 1MB
        Write-Log "Created archive: $ArchivePath (Size: $([math]::Round($ArchiveSize, 2)) MB)"
        
        # Build remote target
        $RemoteTarget = "${LinuxUsername}@${LinuxServer}:${LinuxRemotePath}/"
              
        # Upload archive through SCP
        Write-Log "Transfer archive through SCP to $RemoteTarget"
        
        # Build a process to execute SCP
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo.FileName = "scp"
        $Process.StartInfo.Arguments = "`"$ArchivePath`" `"$RemoteTarget`""
        $Process.StartInfo.UseShellExecute = $false
        $Process.StartInfo.RedirectStandardOutput = $true
        $Process.StartInfo.RedirectStandardError = $true
        $Process.StartInfo.CreateNoWindow = $false
        
        # Event handler to capture output
        $OutputBuilder = New-Object System.Text.StringBuilder
        $ErrorBuilder = New-Object System.Text.StringBuilder
        
        $OutputHandler = {
            if (-not [String]::IsNullOrEmpty($EventArgs.Data)) {
                [void]$OutputBuilder.AppendLine($EventArgs.Data)
            }
        }
        
        $ErrorHandler = {
            if (-not [String]::IsNullOrEmpty($EventArgs.Data)) {
                [void]$ErrorBuilder.AppendLine($EventArgs.Data)
            }
        }
        
        $OutputEvent = Register-ObjectEvent -InputObject $Process -EventName "OutputDataReceived" -Action $OutputHandler
        $ErrorEvent = Register-ObjectEvent -InputObject $Process -EventName "ErrorDataReceived" -Action $ErrorHandler
        
        # Start process
        [void]$Process.Start()
        $Process.BeginOutputReadLine()
        $Process.BeginErrorReadLine()
        $Process.WaitForExit()
        
        # Clean events
        Unregister-Event -SourceIdentifier $OutputEvent.Name
        Unregister-Event -SourceIdentifier $ErrorEvent.Name
        
        # Check output code
        if ($Process.ExitCode -eq 0) {
            Write-Log "SCP transfer succeeded"
            
            # Display detailed output
            $Output = $OutputBuilder.ToString()
            if (-not [String]::IsNullOrEmpty($Output)) {
                Write-Log "Transfer details: $Output"
            }
            
            # Remove local archive if selected
            if ($DeleteLocalArchiveAfterTransfer -and (Test-Path -Path $ArchivePath)) {
                Remove-Item -Path $ArchivePath -Force
	Get-ChildItem -Path $SourcePath -Include *.* -Recurse | foreach { $_.Delete()}
                Write-Log "Local archive deleted"
            }
        } else {
            Write-Log "SCP transfer failed with code $($Process.ExitCode))" -Level "ERROR"
            
            # Display errors
            $Error = $ErrorBuilder.ToString()
            if (-not [String]::IsNullOrEmpty($Error)) {
                Write-Log "SCP error: $Error" -Level "ERROR"
            }
        }
    } else {
        Write-Log "Failure while zipping archive" -Level "ERROR"
        exit 1
    }
  
    Write-Log "Operation finished"
    
} catch {
    Write-Log "Error happened: $_" -Level "ERROR"
    
    # Clean in case of error
    if ($CompressBeforeTransfer -and $DeleteLocalArchiveAfterTransfer -and (Test-Path -Path $ArchivePath)) {
        Remove-Item -Path $ArchivePath -Force
        Write-Log "Temporary archive deleted" -Level "WARNING"
    }
    
    exit 1
}