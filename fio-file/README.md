# FIO benchmarking (Linux / file — NFS, SMB, local FS)

Linux port of the Windows NVMe-oF toolkit: same job catalog and
run → parse → plot pipeline, targeted at **files on a mounted filesystem**
(NFS, SMB/CIFS, or local). Not raw block devices.

**WARNING:** Jobs create/overwrite large files under the target directory.
Confirm the mount path and free space before every run.

## Job catalog

All jobs use incompressible buffers (`refill_buffers=1`, `randrepeat=0`,
`buffer_compress_percentage=0`, `dedupe_percentage=0`) so VAST reduction does
not skew results.

Defaults (override at runtime):

- `ioengine=libaio`
- `directory=/mnt/vast/fio`
- `filename=bench`
- `size=100G`

| File | Purpose |
|------|---------|
| `vast-p01-p06-p09-baseline.ini` | Baseline: 4K IOPS, 64K, 1M + latency log |
| `vast-p02-qd-tuning.ini` | Queue-depth / numjobs sweep |
| `vast-infrastructure-steady-state.ini` | Long mixed + streaming load for env deltas |
| `fiotests_standard.ini` | Enterprise mixed (OLTP / VDI / backup) |
| `fiotests_ml.ini` | AI/ML-oriented patterns |

## Quick smoke test (no job file)

Mount NFS or SMB first, then:

```bash
FIO=$(command -v fio)
DIR=/mnt/vast/fio          # <-- your mount
mkdir -p "$DIR"

# 30s read smoke (creates $DIR/smoke)
fio --name=smoke-read --directory="$DIR" --filename=smoke --size=10G \
  --rw=randread --bs=4k --iodepth=32 --numjobs=1 --runtime=30 \
  --time_based --direct=1 --ioengine=libaio --group_reporting

# optional: 60s mixed
fio --name=smoke-rw --directory="$DIR" --filename=smoke --size=10G \
  --rw=randrw --rwmixread=70 --bs=64k --iodepth=16 --numjobs=1 \
  --runtime=60 --time_based --direct=1 --ioengine=libaio --group_reporting
```

## Pipeline

```bash
cd fio-file

# 1) Run (override path without editing the INI)
./runfio.sh -j ./vast-p01-p06-p09-baseline.ini -d /mnt/vast/fio

# 2) Parse JSON → console + CSV
python3 parse_fio.py ./fio_runs/fio_vast-p01-p06-p09-baseline_1

# 3) Plot IOPS from the same JSON / run folder
python3 generate_plots.py ./fio_runs/fio_vast-p01-p06-p09-baseline_1
```

Requires `fio` (libaio), Python 3, and `matplotlib`.

Run artifacts land under `fio_runs/` (do not commit).

## Notes

- Use a dedicated subdirectory on the share; do not point at production data.
- `direct=1` needs filesystem/mount support for `O_DIRECT` (usual on NFS; verify on SMB).
- For `io_uring`, pass `--ioengine=io_uring` or edit the job `[global]` section.
