# Archived sys_info scripts

Ceph-era / lab-specific collectors kept for reference only.

| File | Was |
|------|-----|
| `dool_osd.sh` | LSI SAS/SATA, SSD vs HDD OSD+cache, `bond0/1` |
| `dool_capture_ceph.sh` | Same hybrid disk logic; many hardcoded NICs |
| `dool_azure_nvme.sh` | Azure NVMe + `eth0` one-off |
| `dool.sh` | Generic wrapper (had `$OUTPUTFILE_PROC` bug) |
| `get_cpu.sh` | SSH loop over fixed `labuser@linux0N` hosts |

Use `../dool_capture.sh` instead.
