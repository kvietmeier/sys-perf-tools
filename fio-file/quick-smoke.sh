#!/usr/bin/env bash
# Manual one-off FIO smoke against a mounted filesystem.
# Does NOT run from cloud-init — invoke after the share is mounted.
#
# Usage:
#   ./quick-smoke.sh /mount/vast/fio
#   DIR=/mount/vast/fio RUNTIME=30 ./quick-smoke.sh
#   ./quick-smoke.sh /mount/vast/fio mixed   # optional 60s mixed after read smoke
#
set -euo pipefail

DIR="${1:-${DIR:-/mount/vast/fio}}"
MODE="${2:-read}"   # read | mixed | both
FIO_BIN="${FIO_BIN:-fio}"
RUNTIME="${RUNTIME:-30}"
SIZE="${SIZE:-10G}"
# Per-host file avoids multi-client collisions on a shared export
HOST_TAG="${HOSTNAME%%.*}"
FILENAME="${FILENAME:-smoke-${HOST_TAG}}"

if ! command -v "$FIO_BIN" >/dev/null 2>&1; then
  echo "[!] fio not found: $FIO_BIN" >&2
  exit 1
fi

if [[ ! -d "$DIR" ]]; then
  echo "[!] directory missing: $DIR (mount the share first)" >&2
  exit 1
fi

run_read() {
  echo "[+] smoke-read → $DIR/$FILENAME (${RUNTIME}s)"
  "$FIO_BIN" --name=smoke-read --directory="$DIR" --filename="$FILENAME" --size="$SIZE" \
    --rw=randread --bs=4k --iodepth=32 --numjobs=1 --runtime="$RUNTIME" \
    --time_based --direct=1 --ioengine=libaio --group_reporting
}

run_mixed() {
  local rt="${MIXED_RUNTIME:-60}"
  echo "[+] smoke-rw → $DIR/$FILENAME (${rt}s)"
  "$FIO_BIN" --name=smoke-rw --directory="$DIR" --filename="$FILENAME" --size="$SIZE" \
    --rw=randrw --rwmixread=70 --bs=64k --iodepth=16 --numjobs=1 \
    --runtime="$rt" --time_based --direct=1 --ioengine=libaio --group_reporting
}

case "$MODE" in
  read)  run_read ;;
  mixed) run_mixed ;;
  both)  run_read; run_mixed ;;
  *)
    echo "Usage: $0 [directory] [read|mixed|both]" >&2
    exit 1
    ;;
esac

echo "[+] smoke complete (no auto-baseline; use ./runfio.sh for packaged jobs)"
