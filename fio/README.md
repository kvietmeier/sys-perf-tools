# fio/ — jobfile builders (Linux block / NVMe)

Scripts that **discover drives and generate FIO job files**, plus a few
example/output INIs under `jobs/`. This is a lab toolkit for raw devices
(`/dev/nvme*`), not a curated workload catalog.

For standardized profiles (baseline, enterprise, AI/ML, etc.) use
**`../fio-jobs/`**.

## What lives here

| Item | Role |
|------|------|
| `create_drivelist.sh` | Enumerate NVMe namespaces → `nvme_drive_list.txt` |
| `create_jobfile_from_drivelist.sh` | Build a multi-drive job INI from a drive list |
| `create_iodepth_jobfile.sh` | Generate a QD-sweep style job for one device |
| `zero_drives.sh` | Prefill/zero drives; refreshes `jobs/zero_out_drives.ini` |
| `latencytests_json.sh` | Single-drive latency CLI loop (JSON out) |
| `latencytests-driveloop-json.sh` | Same idea over a drive list |
| `jobs/*.ini` | Examples / generated outputs — prefer regenerating via scripts |
| `fio-plot-commands.txt` | Notes for `bench-fio` / fio-plot |

**WARNING:** Generators and zero/prefill jobs are destructive to target disks.
Confirm device names before running.

## vs `fio-jobs/`

| | `fio/` | `fio-jobs/` |
|--|--------|-------------|
| Purpose | Build jobfiles for block/drive labs | Run fixed, named workload profiles |
| Typical target | `/dev/nvme*` | File on NFS/SMB/local (`directory=`) |
| Workflow | Script → INI → fio | Edit/override a few globals → `runfio.sh` |
