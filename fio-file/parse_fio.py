"""
FIO JSON parser — extract IOPS / bandwidth / latency and optional CSV export.

Accepts a JSON file, a directory of JSON files, or a runfio.sh run directory
(searches json_output/ recursively). Handles UTF-8 BOM and noisy Windows stdout
wrapping a JSON object.
"""

from __future__ import annotations

import argparse
import csv
import glob
import json
import os
import re
import sys


def resolve_target(target_path: str) -> str:
    """Return a single JSON file path from a file, dir, or fio run folder."""
    if os.path.isfile(target_path):
        return target_path

    if not os.path.isdir(target_path):
        raise FileNotFoundError(f"Invalid path: {target_path}")

    candidates = sorted(
        set(
            glob.glob(os.path.join(target_path, "*.json"))
            + glob.glob(os.path.join(target_path, "json_output", "*.json"))
            + glob.glob(os.path.join(target_path, "**", "*.json"), recursive=True)
        )
    )
    if not candidates:
        raise FileNotFoundError(f"No JSON files found under {target_path}")

    if len(candidates) == 1:
        print(f"[+] Auto-detected JSON: {os.path.relpath(candidates[0], target_path)}")
        return candidates[0]

    print(f"[!] Multiple JSON files found under {target_path}:")
    for idx, path in enumerate(candidates):
        print(f"  [{idx}] {os.path.relpath(path, target_path)}")

    while True:
        try:
            choice = int(input("Select JSON file index: "))
            if 0 <= choice < len(candidates):
                return candidates[choice]
        except ValueError:
            pass
        print("Invalid selection.")


def load_fio_json(json_path: str) -> dict:
    """Load FIO JSON, stripping BOM and extracting object from noisy stdout."""
    with open(json_path, "r", encoding="utf-8-sig") as handle:
        raw_data = handle.read()

    json_match = re.search(r"\{.*\}", raw_data, re.DOTALL)
    if not json_match:
        raise ValueError(f"No JSON payload found in {json_path}")

    try:
        return json.loads(json_match.group(0))
    except json.JSONDecodeError as exc:
        raise ValueError(f"Corrupt JSON payload: {exc}") from exc


def parse_and_export(target_path: str, csv_path: str | None = None) -> list[list]:
    json_path = resolve_target(target_path)
    data = load_fio_json(json_path)
    jobs = data.get("jobs", [])

    print("\n" + "=" * 60)
    print(f" Parsed Metrics: {os.path.basename(json_path)}")
    print("=" * 60)

    parsed_rows: list[list] = []
    for job in jobs:
        name = job.get("jobname", "Unknown")

        r_iops = job.get("read", {}).get("iops", 0)
        r_bw = job.get("read", {}).get("bw", 0) / 1024
        r_lat = job.get("read", {}).get("lat_ns", {}).get("mean", 0) / 1_000_000

        w_iops = job.get("write", {}).get("iops", 0)
        w_bw = job.get("write", {}).get("bw", 0) / 1024
        w_lat = job.get("write", {}).get("lat_ns", {}).get("mean", 0) / 1_000_000

        print(f" Job: {name}")
        print(
            f"  [READ]  IOPS: {r_iops:>10,.2f} | BW: {r_bw:>8,.2f} MB/s | Lat: {r_lat:>6,.2f} ms"
        )
        print(
            f"  [WRITE] IOPS: {w_iops:>10,.2f} | BW: {w_bw:>8,.2f} MB/s | Lat: {w_lat:>6,.2f} ms"
        )
        print("-" * 60)

        parsed_rows.append([name, r_iops, r_bw, r_lat, w_iops, w_bw, w_lat])

    if csv_path is None:
        run_dir = os.path.dirname(json_path)
        # Prefer run root (parent of json_output) when present
        if os.path.basename(run_dir) == "json_output":
            run_dir = os.path.dirname(run_dir)
        csv_path = os.path.join(run_dir, "parsed_metrics.csv")

    os.makedirs(os.path.dirname(os.path.abspath(csv_path)) or ".", exist_ok=True)
    with open(csv_path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "Job Name",
                "Read IOPS",
                "Read BW (MB/s)",
                "Read Lat (ms)",
                "Write IOPS",
                "Write BW (MB/s)",
                "Write Lat (ms)",
            ]
        )
        writer.writerows(parsed_rows)
    print(f"[+] CSV exported: {csv_path}")
    return parsed_rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Parse FIO JSON to console and CSV (default: <run_dir>/parsed_metrics.csv)."
    )
    parser.add_argument("target", help="JSON file, directory, or fio_runs/fio_<job>_<n> folder")
    parser.add_argument(
        "--csv",
        help="CSV export path (default: parsed_metrics.csv next to the run / JSON)",
    )
    args = parser.parse_args(argv)
    try:
        parse_and_export(args.target, args.csv)
    except (FileNotFoundError, ValueError) as exc:
        print(f"[!] {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
