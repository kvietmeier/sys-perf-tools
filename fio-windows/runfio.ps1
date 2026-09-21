<#
.SYNOPSIS
  Run an FIO job file and capture versioned JSON + raw output.

.DESCRIPTION
  Executes fio.exe against a job INI, writing results under fio_runs/fio_<job>_<n>/.
  Optional -Filename overrides the INI target without editing the job file.

  Pipeline:
    1) .\runfio.ps1 -JobFile .\vast-p01-p06-p09-baseline.ini -Filename \\.\PhysicalDrive1
    2) python parse_fio.py .\fio_runs\fio_vast-p01-p06-p09-baseline_1 --csv .\metrics.csv
    3) python generate_plots.py .\fio_runs\fio_vast-p01-p06-p09-baseline_1 --output .\plots\iops.png

.PARAMETER JobFile
  Path to FIO job INI. Default: .\fiotests_ml.ini

.PARAMETER FioPath
  Path to fio.exe. Default: C:\Tools\FIO\fio.exe (matches PowerShell InstallFIO)

.PARAMETER OutputDir
  Root directory for run folders. Default: .\fio_runs

.PARAMETER Filename
  Optional raw device/path passed as fio --filename= (overrides INI filename=)

.EXAMPLE
  .\runfio.ps1 -JobFile .\fiotests_standard.ini -Filename '\\.\PhysicalDrive1'

.NOTES
  WARNING: Jobs targeting \\.\PhysicalDriveX destroy all data on that disk.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$JobFile = ".\fiotests_ml.ini",

    [Parameter(Mandatory = $false)]
    [string]$FioPath = "C:\Tools\FIO\fio.exe",

    [Parameter(Mandatory = $false)]
    [string]$OutputDir = ".\fio_runs",

    [Parameter(Mandatory = $false)]
    [string]$Filename
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $FioExe = (Resolve-Path -Path $FioPath -ErrorAction Stop).Path
    $JobIni = (Resolve-Path -Path $JobFile -ErrorAction Stop).Path

    $JobBaseName = [System.IO.Path]::GetFileNameWithoutExtension($JobIni)
    $Counter = 1
    $TargetJobDir = Join-Path -Path $OutputDir -ChildPath "fio_${JobBaseName}_${Counter}"

    while (Test-Path -Path $TargetJobDir) {
        $Counter++
        $TargetJobDir = Join-Path -Path $OutputDir -ChildPath "fio_${JobBaseName}_${Counter}"
    }

    $JobOutputDir  = New-Item -Path $TargetJobDir -ItemType Directory -Force
    $JsonOutputDir = New-Item -Path (Join-Path -Path $JobOutputDir.FullName -ChildPath "json_output") -ItemType Directory -Force
    $RawOutputDir  = New-Item -Path (Join-Path -Path $JobOutputDir.FullName -ChildPath "raw_output") -ItemType Directory -Force

    $TimeStamp      = Get-Date -Format "yyyyMMdd_HHmmss"
    $JsonOutputFile = Join-Path -Path $JsonOutputDir.FullName -ChildPath "${JobBaseName}_${TimeStamp}.json"
    $RawOutputFile  = Join-Path -Path $RawOutputDir.FullName -ChildPath "${JobBaseName}_${TimeStamp}.txt"

    Write-Host "[+] Executing FIO: $($JobOutputDir.Name)" -ForegroundColor Green
    if ($Filename) {
        Write-Host "    Target device: $Filename" -ForegroundColor Yellow
    }

    Push-Location -Path $RawOutputDir.FullName

    $FioArgs = @(
        $JobIni,
        "--output-format=json",
        "--output=$JsonOutputFile"
    )
    if ($Filename) {
        $FioArgs += "--filename=$Filename"
    }

    & $FioExe @FioArgs *> $RawOutputFile
    $ExitCode = $LASTEXITCODE

    Pop-Location

    if ($ExitCode -ne 0) {
        throw "FIO process terminated with code $ExitCode. Inspect raw output: $RawOutputFile"
    }

    Write-Host "[+] Test completion confirmed." -ForegroundColor Green
    Write-Host "    Target JSON: $JsonOutputFile"
    return $JsonOutputFile
}
catch {
    if ((Get-Location -ErrorAction SilentlyContinue).Path -match "raw_output$") {
        Pop-Location
    }
    Write-Error -Message "Benchmark iteration failed: $_"
    exit 1
}
