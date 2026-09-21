"""
FIO plot generator — bar chart of Read/Write IOPS from FIO JSON.

Uses the same target resolution and JSON loading as parse_fio.py (file, dir,
or runfio run folder; BOM / noisy stdout tolerant).
"""

from __future__ import annotations

import argparse
import os
import sys

import matplotlib.pyplot as plt

from parse_fio import load_fio_json, resolve_target


def generate_graphics(target_path: str, output_png: str) -> None:
    json_path = resolve_target(target_path)
    data = load_fio_json(json_path)

    jobs = data.get("jobs", [])
    if not jobs:
        print("[!] No job data available to plot.")
        return

    names = [j.get("jobname", "Job") for j in jobs]
    read_iops = [j.get("read", {}).get("iops", 0) for j in jobs]
    write_iops = [j.get("write", {}).get("iops", 0) for j in jobs]

    x = range(len(names))
    width = 0.35

    fig, ax = plt.subplots(figsize=(10, 6))
    ax.bar([i - width / 2 for i in x], read_iops, width, label="Read IOPS", color="#2b5c8f")
    ax.bar([i + width / 2 for i in x], write_iops, width, label="Write IOPS", color="#d95f02")

    ax.set_ylabel("IOPS")
    ax.set_title(f"FIO Performance Results: {os.path.basename(json_path)}")
    ax.set_xticks(list(x))
    ax.set_xticklabels(names, rotation=15, ha="right")
    ax.legend()
    ax.grid(axis="y", linestyle="--", alpha=0.5)

    plt.tight_layout()

    out_dir = os.path.dirname(os.path.abspath(output_png))
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    plt.savefig(output_png, dpi=300)
    plt.close()
    print(f"[+] Plot written: {output_png}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate FIO IOPS bar chart from JSON.")
    parser.add_argument("target", help="JSON file, directory, or fio_runs/fio_<job>_<n> folder")
    parser.add_argument(
        "--output",
        help="PNG output path (default: <run_dir>/plots/iops.png)",
    )
    args = parser.parse_args(argv)

    output = args.output
    if not output:
        json_path = resolve_target(args.target)
        run_dir = os.path.dirname(json_path)
        if os.path.basename(run_dir) == "json_output":
            run_dir = os.path.dirname(run_dir)
        output = os.path.join(run_dir, "plots", "iops.png")

    try:
        generate_graphics(args.target, output)
    except (FileNotFoundError, ValueError) as exc:
        print(f"[!] {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
