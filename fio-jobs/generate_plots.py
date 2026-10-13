"""
FIO plot generator — IOPS and throughput bar charts from FIO JSON.

Writes a single side-by-side summary.png. Uses log Y when the dynamic range
is large so 4K and 1M jobs stay readable on the same axes.

Read-only / write-only jobs get one centered bar (not a gapped Read/Write pair).
"""

from __future__ import annotations

import argparse
import os
import sys

import matplotlib.pyplot as plt
from matplotlib.patches import Patch
import numpy as np

from parse_fio import load_fio_json, resolve_target

# FIO JSON "bw" is KiB/s; match parse_fio.py (MB/s = bw / 1024).
_BW_TO_MBS = 1024.0
_LOG_RATIO = 25.0
_READ_COLOR = "#2b5c8f"
_WRITE_COLOR = "#d95f02"
_MIXED_READ = "#2b5c8f"
_MIXED_WRITE = "#d95f02"


def _run_dir_for_json(json_path: str) -> str:
    run_dir = os.path.dirname(json_path)
    if os.path.basename(run_dir) == "json_output":
        run_dir = os.path.dirname(run_dir)
    return run_dir


def _use_log(vals: list[float]) -> bool:
    positive = [v for v in vals if v > 0]
    if len(positive) < 2:
        return False
    return (max(positive) / min(positive)) >= _LOG_RATIO


def _fmt(height: float) -> str:
    if height >= 1000:
        return f"{height:,.0f}"
    if height >= 10:
        return f"{height:.1f}"
    return f"{height:.2f}"


def _annotate_bar(ax, x: float, height: float, *, log: bool) -> None:
    if height <= 0:
        return
    ypos = height * (1.15 if log else 1.02)
    ax.text(x, ypos, _fmt(height), ha="center", va="bottom", fontsize=8)


def _panel(
    ax,
    names: list[str],
    read_vals: list[float],
    write_vals: list[float],
    *,
    ylabel: str,
    title: str,
) -> None:
    x = np.arange(len(names), dtype=float)
    width = 0.55
    pair_width = 0.35
    all_vals = [v for v in list(read_vals) + list(write_vals) if v > 0]
    log = _use_log(all_vals)

    for i, name in enumerate(names):
        r = read_vals[i]
        w = write_vals[i]
        if r > 0 and w > 0:
            # True mixed job — side-by-side pair centered on tick
            ax.bar(x[i] - pair_width / 2, r, pair_width, color=_MIXED_READ)
            ax.bar(x[i] + pair_width / 2, w, pair_width, color=_MIXED_WRITE)
            _annotate_bar(ax, x[i] - pair_width / 2, r, log=log)
            _annotate_bar(ax, x[i] + pair_width / 2, w, log=log)
        elif r > 0:
            ax.bar(x[i], r, width, color=_READ_COLOR)
            _annotate_bar(ax, x[i], r, log=log)
        elif w > 0:
            ax.bar(x[i], w, width, color=_WRITE_COLOR)
            _annotate_bar(ax, x[i], w, log=log)

    ax.set_ylabel(ylabel)
    ax.set_title(title)
    ax.set_xticks(x)
    ax.set_xticklabels(names, rotation=20, ha="right", fontsize=8)
    ax.legend(
        handles=[
            Patch(facecolor=_READ_COLOR, label="Read"),
            Patch(facecolor=_WRITE_COLOR, label="Write"),
        ],
        loc="best",
        fontsize=8,
    )
    ax.grid(axis="y", linestyle="--", alpha=0.5)
    ax.set_xlim(-0.6, len(names) - 0.4)

    if log and all_vals:
        ax.set_yscale("log")
        ax.set_ylim(bottom=min(all_vals) / 3.0)


def generate_graphics(
    target_path: str,
    summary_png: str,
    iops_png: str | None = None,
    throughput_png: str | None = None,
) -> None:
    json_path = resolve_target(target_path)
    data = load_fio_json(json_path)

    jobs = data.get("jobs", [])
    if not jobs:
        print("[!] No job data available to plot.")
        return

    base = os.path.basename(json_path)
    names = [j.get("jobname", "Job") for j in jobs]
    read_iops = [float(j.get("read", {}).get("iops", 0) or 0) for j in jobs]
    write_iops = [float(j.get("write", {}).get("iops", 0) or 0) for j in jobs]
    read_bw = [float(j.get("read", {}).get("bw", 0) or 0) / _BW_TO_MBS for j in jobs]
    write_bw = [float(j.get("write", {}).get("bw", 0) or 0) / _BW_TO_MBS for j in jobs]

    max_mbs = max(read_bw + write_bw + [0.0])
    if max_mbs >= 1024:
        thr_ylabel = "Throughput (GB/s)"
        read_thr = [v / 1024.0 for v in read_bw]
        write_thr = [v / 1024.0 for v in write_bw]
    else:
        thr_ylabel = "Throughput (MB/s)"
        read_thr = read_bw
        write_thr = write_bw

    fig, (ax0, ax1) = plt.subplots(1, 2, figsize=(14, 6))
    _panel(ax0, names, read_iops, write_iops, ylabel="IOPS", title="IOPS")
    _panel(ax1, names, read_thr, write_thr, ylabel=thr_ylabel, title="Throughput")
    fig.suptitle(f"FIO: {base}", fontsize=12)
    fig.tight_layout()

    out_dir = os.path.dirname(os.path.abspath(summary_png))
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    fig.savefig(summary_png, dpi=200)
    plt.close(fig)
    print(f"[+] Plot written: {summary_png}")

    if iops_png:
        fig, ax = plt.subplots(figsize=(10, 6))
        _panel(ax, names, read_iops, write_iops, ylabel="IOPS", title=f"FIO IOPS: {base}")
        fig.tight_layout()
        os.makedirs(os.path.dirname(os.path.abspath(iops_png)) or ".", exist_ok=True)
        fig.savefig(iops_png, dpi=200)
        plt.close(fig)
        print(f"[+] Plot written: {iops_png}")

    if throughput_png:
        fig, ax = plt.subplots(figsize=(10, 6))
        _panel(
            ax,
            names,
            read_thr,
            write_thr,
            ylabel=thr_ylabel,
            title=f"FIO Throughput: {base}",
        )
        fig.tight_layout()
        os.makedirs(os.path.dirname(os.path.abspath(throughput_png)) or ".", exist_ok=True)
        fig.savefig(throughput_png, dpi=200)
        plt.close(fig)
        print(f"[+] Plot written: {throughput_png}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate FIO IOPS / throughput charts from JSON."
    )
    parser.add_argument("target", help="JSON file, directory, or fio_runs/fio_<job>_<n> folder")
    parser.add_argument(
        "--output",
        help="Summary PNG path (default: <run_dir>/plots/summary.png)",
    )
    parser.add_argument(
        "--also-split",
        action="store_true",
        help="Also write separate iops.png and throughput.png",
    )
    args = parser.parse_args(argv)

    try:
        json_path = resolve_target(args.target)
        run_dir = _run_dir_for_json(json_path)
        plots_dir = os.path.join(run_dir, "plots")

        summary_png = args.output or os.path.join(plots_dir, "summary.png")
        iops_png = None
        thr_png = None
        if args.also_split:
            sibling = os.path.dirname(os.path.abspath(summary_png))
            iops_png = os.path.join(sibling, "iops.png")
            thr_png = os.path.join(sibling, "throughput.png")

        generate_graphics(args.target, summary_png, iops_png, thr_png)
    except (FileNotFoundError, ValueError) as exc:
        print(f"[!] {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
