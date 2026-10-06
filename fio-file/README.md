# FIO benchmarking (Linux / file — NFS, SMB, local FS)

Standardized workload profiles for storage performance testing. Same I/O
patterns as the Windows / NVMe block catalog — adapted here for **files on a
mounted filesystem** (NFS, SMB/CIFS, or local). The run → parse → plot pipeline
lives alongside the jobs.

**WARNING:** Jobs create/overwrite large files under the target directory.
Confirm the mount path and free space before every run.

## Mount convention

Default work path is under **`/mount/vast`** (lab client mount root). Override
with `./runfio.sh -d` — do not hard-require that tree.

| Path | Role |
|------|------|
| `/mount/vast` | Typical NFS/SMB mount root |
| `/mount/vast/fio` | Default FIO work directory |

## Job catalog

All profiles use incompressible buffers (`refill_buffers=1`, `randrepeat=0`,
`buffer_compress_percentage=0`, `dedupe_percentage=0`) so storage reduction
features do not skew results.

Defaults for file jobs (override at runtime):

- `ioengine=libaio`
- `directory=/mount/vast/fio`
- `filename=bench`
- `size=100G`

| File | Purpose |
|------|---------|
| `baseline-bs-spectrum.ini` | Short block-size spectrum: 4K IOPS, 64K, 1M + latency log |
| `sweep-qd-4k.ini` | Queue-depth / numjobs sweep (4K rand read) |
| `soak-steady-state.ini` | Long mixed + streaming load for env / soak deltas |
| `workload-enterprise.ini` | Enterprise mixed (OLTP / VDI / backup / streaming) |
| `workload-ai-ml.ini` | AI/ML-oriented patterns (ingest, KV, checkpoint, RAG) |
| `link-sat-dual-path.ini` | Dual-path link saturation (two block devices, 1M seq) |

`link-sat-dual-path.ini` is the exception: raw NVMe block devices, not
`directory=` files. See below.

## Adapting jobs for platform / target

Workload sections (`rw=`, `bs=`, `iodepth=`, `numjobs=`, stonewalls) are the
**same** across platforms. Only a few `[global]` / target lines change.

### Linux file (this folder — default)

```ini
ioengine=libaio
directory=/mount/vast/fio
filename=bench
size=100G
# no thread=  (processes are fine)
```

Override without editing the INI:

```bash
./runfio.sh -j ./baseline-bs-spectrum.ini -d /mount/vast/fio -f bench -s 100G
```

### Linux block (NVMe / NVMe-oF)

```ini
ioengine=libaio          # or io_uring
filename=/dev/nvme0n1    # confirm device; destructive
size=50G                 # or omit to use whole device carefully
# remove directory=
```

### Windows block (NVMe / NVMe-oF)

```ini
ioengine=windowsaio
thread=1
filename=\\.\PhysicalDrive1   # confirm disk number; destructive
# remove directory=
```

### Cheat sheet

| Setting | Linux file | Linux block | Windows block |
|---------|------------|-------------|---------------|
| `ioengine` | `libaio` | `libaio` / `io_uring` | `windowsaio` |
| `thread` | omit | omit | `1` (typical) |
| Target | `directory=` + `filename=` | `filename=/dev/nvme…` | `filename=\\.\PhysicalDriveN` |
| `size` | file size (e.g. `100G`) | limit or full device | limit or full disk |

Everything else in the profile (block sizes, mix ratios, QD, runtimes) stays put.
Copy a job, change the lines above, run.

For dual-path / multi-device jobs (`link-sat-dual-path.ini`), set **each**
job section’s `filename=` (two devices). Runtime `-d`/`-f` overrides do not
apply cleanly — edit the INI and run `fio` directly.

## Dual-path link saturation (`link-sat-dual-path.ini`)

Load two independent data paths in parallel toward theoretical line rate
(e.g. 2×100 GbE ≈ 25 GB/s or 2×200 GbE ≈ 50 GB/s L2 ceilings — not guarantees).

1. Two independent paths (distinct local IP / fabric path per NIC port).
2. Two separate block devices — edit both `filename=` lines.
3. Pin CPUs to the NIC’s NUMA node (`cpus_allowed` or `numa_cpu_nodes`).

```bash
# NIC NUMA affinity
for n in /sys/class/net/*/device/numa_node; do
  echo "$(echo "$n" | cut -d/ -f5) numa=$(cat "$n")"
done

# Edit /dev/nvme* in the INI, then:
fio ./link-sat-dual-path.ini
```

For writes, set `rw=write` in `[global]`. Destructive — confirm devices first.

## Quick smoke test (no job file)

```bash
FIO=$(command -v fio)
DIR=/mount/vast/fio          # <-- your mount
mkdir -p "$DIR"

fio --name=smoke-read --directory="$DIR" --filename=smoke --size=10G \
  --rw=randread --bs=4k --iodepth=32 --numjobs=1 --runtime=30 \
  --time_based --direct=1 --ioengine=libaio --group_reporting
```

## Pipeline

```bash
cd fio-file

./runfio.sh -j ./baseline-bs-spectrum.ini -d /mount/vast/fio

python3 parse_fio.py ./fio_runs/fio_baseline-bs-spectrum_1
python3 generate_plots.py ./fio_runs/fio_baseline-bs-spectrum_1
```

Requires `fio` (libaio), Python 3, and `matplotlib`.

Run artifacts land under `fio_runs/` (do not commit).

## Notes

- Use a dedicated subdirectory on the share; do not point at production data.
- `direct=1` needs filesystem/mount support for `O_DIRECT` (usual on NFS; verify on SMB).
- For `io_uring`, pass `--ioengine=io_uring` or edit the job `[global]` section.
