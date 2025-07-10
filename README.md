# Powershell
Scripts powershell divers et variés :)

## DumpEventLog.ps1
This script will dump logs containing information about "Application" and "System" events.

## LogUptimeData.ps1
This script will log current uptime in a dedicated file. If the file does not exist, it will create it with the right header.

## RotateBackupFiles.ps1
This script will scan the content of a specified directory, look for all CSV files. It will keep all files generated within a week. It will keep one file (per type) per day if it is older than a week. And all files older than 90 days will be deleted.

## ScpBackup.ps1
This script will generate an archive based on a specified directory, and it will send it to a remote (Linux) machine using SCP.

## CodeMeterDustFile.ps1
This script will call `cmu.exe` to generate a `cmdust` file.
