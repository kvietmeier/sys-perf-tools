# FIO benchmarking (Windows NVMe-oF / VAST)

Job files and a small run → parse → plot toolchain for raw block devices
(`\\.\PhysicalDriveX`) attached via NVMe-oF (e.g. StarWind initiator → VAST).

**WARNING:** These jobs are destructive to the target disk. Confirm the drive
number before every run.

## Job catalog

All jobs use incompressible buffers (`refill_buffers=1`, `randrepeat=0`,
`buffer_compress_percentage=0`, `dedupe_percentage=0`) so VAST reduction does
not skew results. Default `filename=\\.\PhysicalDriveX` — override at runtime.

| File | Purpose |
|------|---------|
| `vast-p01-p06-p09-baseline.ini` | FRD baseline: 4K IOPS, 64K, 1M + latency log |
| `vast-p02-qd-tuning.ini` | Queue-depth / numjobs sweep |
| `vast-infrastructure-steady-state.ini` | Long mixed + streaming load for env deltas |
| `fiotests_standard.ini` | Enterprise mixed (OLTP / VDI / backup) |
| `fiotests_ml.ini` | AI/ML-oriented patterns |

## Quick smoke test (no job file)

Prove the data path after StarWind → VAST connect. Destructive — confirm disk number first.
Run elevated. For **writes**, offline the disk so Windows does not hold a volume lock.

```powershell
$Fio  = "C:\Tools\FIO\fio.exe"
$Disk = 1                      # <-- your disk
$Dev  = "\\.\PhysicalDrive$Disk"

Set-Disk -Number $Disk -IsReadOnly $false
Set-Disk -Number $Disk -IsOffline $true

# 30s read smoke
& $Fio --name=smoke-read --filename=$Dev --rw=randread --bs=4k `
  --iodepth=32 --numjobs=1 --runtime=30 --time_based --thread=1 `
  --direct=1 --ioengine=windowsaio --group_reporting

# optional: 60s mixed (easier to see on VAST; needs offline disk)
& $Fio --name=smoke-rw --filename=$Dev --rw=randrw --rwmixread=70 --bs=64k `
  --iodepth=16 --numjobs=1 --runtime=60 --time_based --thread=1 `
  --direct=1 --ioengine=windowsaio --group_reporting

Set-Disk -Number $Disk -IsOffline $false
```

CLI path proof (single VIP vs all portals) is in  
[`../StarWind/KB-Windows-NVMe-TCP-Host-Prep.md`](../StarWind/KB-Windows-NVMe-TCP-Host-Prep.md) §12.

## Pipeline

```powershell
cd fio

# 1) Run (override device without editing the INI)
.\runfio.ps1 -JobFile .\vast-p01-p06-p09-baseline.ini -Filename '\\.\PhysicalDrive1'

# 2) Parse JSON → console + CSV (accepts run folder; finds json_output\)
python parse_fio.py .\fio_runs\fio_vast-p01-p06-p09-baseline_1
# optional: python parse_fio.py .\fio_runs\fio_vast-p01-p06-p09-baseline_1 --csv .\custom.csv

# 3) Plot IOPS from the same JSON / run folder
python generate_plots.py .\fio_runs\fio_vast-p01-p06-p09-baseline_1
# optional: python generate_plots.py .\fio_runs\fio_vast-p01-p06-p09-baseline_1 --output .\report.png
```

Requires `fio.exe` (default `C:\Tools\FIO\fio.exe` from `02-OptimizeForVAST.ps1` / InstallFIO)
and Python 3 with `matplotlib` (installed by `01-DeployOSBaseline.ps1` and `02-OptimizeForVAST.ps1`).

Run artifacts land under `fio_runs/` (gitignored).

## Related

- FRD: [`../StarWind/Starwind-FRD.md`](../StarWind/Starwind-FRD.md)
- Host prep: `PowerShell/01-DeployOSBaseline.ps1`, `02-OptimizeForVAST.ps1` (FIO + Python/matplotlib), `03-DeployStarwind.ps1`
