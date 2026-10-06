#!/usr/bin/env bash
###==========================================================================================================###
#  dool_capture.sh — parameterized dool CSV capture for host performance work
#
#  Modes:
#    cpu  CPU / memory / scheduling (context switches, interrupts, locks, IPC, VM)
#    io   General IOPS / block throughput (requests, tps, util, wait, aio)
#
#  Also: status | stop
#
#  Requires: dool (https://github.com/scottchiefbaker/dool)
#    dstat is gone / unmaintained — do not use dstat. Build dool from source via
#    the system setup scripts so it is on PATH on lab hosts.
###==========================================================================================================###

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  dool_capture.sh cpu|io [options]
  dool_capture.sh status|stop

Modes:
  cpu   CPU, memory, context switches/interrupts (--sys), locks, IPC, VM/page/swap,
        process/load, top CPU/mem/latency consumers
  io    Disk IOPS/throughput: --io, --disk, --disk-tps, --disk-util, --disk-wait,
        --aio, top bio/io; optional --net

Options:
  -i, --interval SEC   Sample interval in seconds (default: 1)
  -c, --count N        Number of samples (default: 380; 0 = run until stop)
  -o, --outdir DIR     Output directory (default: ~/dool)
  -D, --disks LIST     Comma-separated disks for io mode (default: auto via lsblk)
  -N, --nets LIST      Comma-separated NICs (optional; enables --net)
  -f, --foreground     Run in foreground (default: background)
  -n, --dry-run        Print dool command(s) and exit
  -h, --help           Show this help

Examples:
  dool_capture.sh cpu -i 5 -c 120
  dool_capture.sh io -D nvme0n1,nvme1n1 -i 1 -c 600
  dool_capture.sh io -N eth0,total
  dool_capture.sh stop

Note:
  dool --lock is POSIX/flock file-lock stats (closest built-in to lock pressure).
  Per-process futex/mutex contention needs perf/bpf tooling, not dool.
EOF
}

die() { echo "error: $*" >&2; exit 1; }

require_dool() {
  command -v dool >/dev/null 2>&1 || die \
    "dool not found in PATH (dstat is gone — install/build dool from the system setup scripts)"
}

# Block devices only (skip partitions / LVM / md members shown as disk by some tools)
discover_disks() {
  lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2 == "disk" { print $1 }' | paste -sd, -
}

stamp() { date +%m%d_%H%M%S; }

MODE=""
INTERVAL=1
COUNT=380
OUTDIR="${HOME}/dool"
DISKS=""
NETS=""
FOREGROUND=0
DRY_RUN=0

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

case "$1" in
  -h|--help) usage; exit 0 ;;
  cpu|io|status|stop) MODE="$1"; shift ;;
  *) die "unknown mode '$1' (use cpu|io|status|stop)" ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--interval) INTERVAL="${2:?}"; shift 2 ;;
    -c|--count) COUNT="${2:?}"; shift 2 ;;
    -o|--outdir) OUTDIR="${2:?}"; shift 2 ;;
    -D|--disks) DISKS="${2:?}"; shift 2 ;;
    -N|--nets) NETS="${2:?}"; shift 2 ;;
    -f|--foreground) FOREGROUND=1; shift ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

PIDFILE="${OUTDIR}/.dool_capture.pids"

status_cmd() {
  if [[ ! -f "$PIDFILE" ]]; then
    echo "No active capture (missing $PIDFILE)"
    return 1
  fi
  local alive=0
  while read -r pid tag; do
    [[ -z "${pid:-}" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      echo "running  pid=$pid  $tag"
      alive=1
    else
      echo "stale    pid=$pid  $tag"
    fi
  done < "$PIDFILE"
  [[ $alive -eq 1 ]]
}

stop_cmd() {
  if [[ ! -f "$PIDFILE" ]]; then
    echo "No pidfile at $PIDFILE"
    return 0
  fi
  while read -r pid tag; do
    [[ -z "${pid:-}" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      echo "stopped pid=$pid ($tag)"
    fi
  done < "$PIDFILE"
  rm -f "$PIDFILE"
}

if [[ "$MODE" == "status" ]]; then
  status_cmd || true
  exit 0
fi

if [[ "$MODE" == "stop" ]]; then
  stop_cmd
  exit 0
fi

if [[ $DRY_RUN -eq 0 ]]; then
  require_dool
  mkdir -p "$OUTDIR"
fi

TS=$(stamp)
DELAY_ARGS=("$INTERVAL")
if [[ "$COUNT" -gt 0 ]]; then
  DELAY_ARGS+=("$COUNT")
fi

run_dool() {
  local tag="$1"
  shift
  local outfile="${OUTDIR}/dool_${MODE}_${tag}.${TS}.csv"
  local -a cmd=(dool "$@" --output "$outfile" "${DELAY_ARGS[@]}")

  echo "${cmd[*]}"
  if [[ $DRY_RUN -eq 1 ]]; then
    return 0
  fi

  if [[ $FOREGROUND -eq 1 ]]; then
    echo "Writing $outfile"
    "${cmd[@]}"
  else
    "${cmd[@]}" &>/dev/null &
    local pid=$!
    disown "$pid" 2>/dev/null || true
    echo "$pid $tag:$outfile" >>"$PIDFILE"
    echo "started pid=$pid -> $outfile"
  fi
}

case "$MODE" in
  cpu)
    # Scheduling pressure: --sys (irq + csw), --proc (run/block), --lock / --ipc
    # Memory path: --mem/--mem-adv/--swap/--vm/--page
    run_dool sys \
      --time --noupdate \
      --cpu --cpu-adv \
      --mem --mem-adv --swap \
      --sys --proc --load \
      --vm --page \
      --lock --ipc --fs \
      --top-cpu --top-mem --top-latency
    ;;

  io)
    if [[ -z "$DISKS" ]]; then
      DISKS=$(discover_disks)
    fi
    [[ -n "$DISKS" ]] || die "no disks found; pass -D name1,name2"

    # total + discovered devices
    local_disk_list="total,${DISKS}"

    io_common=(
      --time --noupdate
      --io
      --disk -D "$local_disk_list"
      --disk-tps --disk-util --disk-wait --disk-avgqu
      --aio
      --top-bio --top-io
    )

    if [[ -n "$NETS" ]]; then
      io_common+=(--net -N "$NETS")
    fi

    run_dool block "${io_common[@]}"
    ;;
esac

if [[ $DRY_RUN -eq 0 && $FOREGROUND -eq 0 ]]; then
  echo "Use: $0 status | $0 stop"
fi
