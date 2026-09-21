#!/usr/bin/env bash
# Run an FIO job file and capture versioned JSON + raw output (Linux / file).
#
# Pipeline:
#   1) ./runfio.sh -j ./vast-p01-p06-p09-baseline.ini -d /mnt/vast/fio
#   2) python3 parse_fio.py ./fio_runs/fio_vast-p01-p06-p09-baseline_1
#   3) python3 generate_plots.py ./fio_runs/fio_vast-p01-p06-p09-baseline_1
#
# WARNING: Jobs write large files under the target directory.

set -euo pipefail

JOB_FILE="./fiotests_ml.ini"
FIO_BIN="${FIO_BIN:-fio}"
OUTPUT_DIR="./fio_runs"
DIRECTORY=""
FILENAME=""
SIZE=""

usage() {
  cat <<'USAGE'
Usage: ./runfio.sh [-j job.ini] [-d directory] [-f filename] [-s size] [-o output_dir] [-b fio_binary]

  -j  Job INI (default: ./fiotests_ml.ini)
  -d  Override fio directory= (mount path, e.g. /mnt/vast/fio)
  -f  Override fio filename=  (basename under directory, e.g. bench)
  -s  Override fio size=      (e.g. 100G)
  -o  Run output root (default: ./fio_runs)
  -b  fio binary (default: fio, or $FIO_BIN)
  -h  Help
USAGE
}

while getopts ":j:d:f:s:o:b:h" opt; do
  case "$opt" in
    j) JOB_FILE=$OPTARG ;;
    d) DIRECTORY=$OPTARG ;;
    f) FILENAME=$OPTARG ;;
    s) SIZE=$OPTARG ;;
    o) OUTPUT_DIR=$OPTARG ;;
    b) FIO_BIN=$OPTARG ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage; exit 1 ;;
  esac
done

if ! command -v "$FIO_BIN" >/dev/null 2>&1; then
  echo "[!] fio not found: $FIO_BIN" >&2
  exit 1
fi

JOB_INI=$(cd "$(dirname "$JOB_FILE")" && pwd)/$(basename "$JOB_FILE")
if [[ ! -f "$JOB_INI" ]]; then
  echo "[!] Job file not found: $JOB_FILE" >&2
  exit 1
fi

JOB_BASE=$(basename "$JOB_INI" .ini)
COUNTER=1
TARGET_JOB_DIR="${OUTPUT_DIR}/fio_${JOB_BASE}_${COUNTER}"
while [[ -e "$TARGET_JOB_DIR" ]]; do
  COUNTER=$((COUNTER + 1))
  TARGET_JOB_DIR="${OUTPUT_DIR}/fio_${JOB_BASE}_${COUNTER}"
done

mkdir -p "$TARGET_JOB_DIR/json_output" "$TARGET_JOB_DIR/raw_output"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
JSON_OUT="$TARGET_JOB_DIR/json_output/${JOB_BASE}_${TIMESTAMP}.json"
RAW_OUT="$TARGET_JOB_DIR/raw_output/${JOB_BASE}_${TIMESTAMP}.txt"

echo "[+] Executing FIO: $(basename "$TARGET_JOB_DIR")"
[[ -n "$DIRECTORY" ]] && echo "    directory: $DIRECTORY"
[[ -n "$FILENAME" ]] && echo "    filename:  $FILENAME"
[[ -n "$SIZE" ]] && echo "    size:      $SIZE"

FIO_ARGS=(
  "$JOB_INI"
  "--output-format=json"
  "--output=$JSON_OUT"
)
[[ -n "$DIRECTORY" ]] && FIO_ARGS+=("--directory=$DIRECTORY")
[[ -n "$FILENAME" ]] && FIO_ARGS+=("--filename=$FILENAME")
[[ -n "$SIZE" ]] && FIO_ARGS+=("--size=$SIZE")

(
  cd "$TARGET_JOB_DIR/raw_output"
  "$FIO_BIN" "${FIO_ARGS[@]}" >"$RAW_OUT" 2>&1
)

echo "[+] Test completion confirmed."
echo "    Target JSON: $JSON_OUT"
printf '%s\n' "$JSON_OUT"
