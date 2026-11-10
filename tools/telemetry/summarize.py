"""Totals play reports from one or more save files (the measured play time for PRs).

Reads the "page_stats" of each save (user://save_slot_<n>.json) and prints time,
deaths and hits per region, plus the average across saves.
Run: python3 tools/telemetry/summarize.py save_slot_1.json [save_slot_2.json ...]
"""
import json
import sys
from collections import defaultdict

REGIONS = [("prologue", "The Shelf"), ("thistledown", "Thistledown"), ("lanternfold", "Lanternfold"),
           ("marsh", "Watermark Marsh"), ("peaks", "The Spine Peaks"), ("fair", "Gatefold Fair"),
           ("index", "The Index"), ("finale", "The Gutter (finale)"), ("margins", "The Blank Margins"),
           ("postgame", "The Last Margin"), ("hub", "The Spine (hub)"), ("combat_lab", "Combat Lab")]


def region(path):
    folder = path.split("/levels/")[-1].split("/")[0]
    return dict(REGIONS).get(folder, "Margin and interludes")


def main(paths):
    totals = defaultdict(lambda: [0.0, 0, 0])
    for p in paths:
        stats = json.load(open(p)).get("page_stats", {})
        for page, s in stats.items():
            t = totals[region(page)]
            t[0] += s.get("t", 0.0)
            t[1] += int(s.get("d", 0))
            t[2] += int(s.get("h", 0))
    n = max(len(paths), 1)
    grand = 0.0
    print("%-30s %10s %8s %8s   (average of %d saves)" % ("region", "minutes", "deaths", "hits", n))
    for name, (t, d, h) in sorted(totals.items(), key=lambda kv: -kv[1][0]):
        grand += t
        print("%-30s %10.1f %8.1f %8.1f" % (name, t / 60 / n, d / n, h / n))
    print("%-30s %10.1f" % ("total", grand / 60 / n))


if __name__ == "__main__":
    main(sys.argv[1:])
