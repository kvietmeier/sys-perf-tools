# sys-perf-tools

Storage and host **performance** tooling — fio job generation, drive prep, sys_info collectors, hugepages, packet monitors.
Kept separate from `system-tools` so disk/NIC stress scripts are not mixed with shell env or day-to-day utilities.

## Layout

| Path | Purpose |
|------|---------|
| `fio/` | Job files, drive lists, latency/bench wrappers |
| `fio-file/` | Linux file-based FIO (NFS/SMB/local) — jobs + run/parse/plot |
| `sys_info/` | dool/system inventory capture helpers |
| `hugepages_settings.sh` | Hugepage tuning |
| `pkt_monitor.sh` | Packet/network monitoring helper |
