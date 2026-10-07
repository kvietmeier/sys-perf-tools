# sys_info

Host inventory and **dool** CSV capture helpers for performance runs.

## Why dool (not dstat)

**dstat is gone** — unmaintained/removed from modern distros. These scripts use **[dool](https://github.com/scottchiefbaker/dool)** (the maintained dstat successor) instead.

Ensure `dool` is on `PATH` before running captures.

## Active

| Script | Purpose |
|--------|---------|
| `dool_capture.sh` | Parameterized dool capture — `cpu` or `io` modes |
| `getssdinfo.sh` | Block device table: WCE, vendor, model, size |
| `getcache.sh` | Write-cache (WCE) sweep via `sdparm` |
| `system_info.sh` | Quick WSL / Azure / GCP / AWS environment sniff |

### dool_capture.sh

Requires `dool` on `PATH` (see above).

```bash
# CPU / memory / scheduling (context switches, interrupts, locks, IPC, VM)
./dool_capture.sh cpu -i 5 -c 120

# General IOPS / block stats (auto-discovers disks via lsblk)
./dool_capture.sh io -i 1 -c 600

# Pin devices / optional NICs
./dool_capture.sh io -D nvme0n1,nvme1n1 -N eth0,total

./dool_capture.sh status
./dool_capture.sh stop
```

Defaults: interval `1s`, count `380`, output `~/dool/`, background with a pidfile.

| Mode | What it collects |
|------|------------------|
| `cpu` | `--cpu/--cpu-adv`, `--mem/--mem-adv/--swap`, `--sys` (IRQ + context switches), `--proc/--load`, `--vm/--page`, `--lock/--ipc/--fs`, top CPU/mem/latency |
| `io` | `--io`, `--disk` (+ tps/util/wait/avgqu), `--aio`, top bio/io; optional `--net` via `-N` |

`dool --lock` is POSIX/flock file-lock counters — useful as a lock-pressure signal, not per-thread futex/mutex. For that, use `perf` / bpf tools.

## Archive

`archive/` holds older Ceph/lab-specific dool wrappers (LSI SAS/HDD OSD hybrid, Azure NVMe one-off. Kept for reference; prefer `dool_capture.sh`.
