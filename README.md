# sys-perf-tools

Storage and host **performance** tooling — fio job generation, drive prep, sys_info collectors, hugepages, packet monitors. Separate from `system-tools` which are day-to-day utilities.

## Layout

| Path | Purpose |
|------|---------|
| `fio/` | Scripts that build FIO jobfiles for Linux block/NVMe labs (drive lists, zero/prefill, latency loops) |
| `fio-jobs/` | Curated FIO workload profiles + run/parse/plot (Linux file defaults; see README for platform adapt) |
| `sys_info/` | dool CSV capture (`cpu` / `io`; dstat is gone) + disk inventory; Ceph-era scripts in `archive/` |
| `hugepages_settings.sh` | Hugepage tuning |
| `networkmonitor.sh` | Identify cloud network throttling, bandwidth limits, and PPS credit exhaustion |
| `pkt_monitor.sh` | Packet/network monitoring helper |
