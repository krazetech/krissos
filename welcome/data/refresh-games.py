#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Kraze Tech
"""Refresh games.json from the AreWeAntiCheatYet list (MIT). Run from anywhere:
    python welcome/data/refresh-games.py
Keeps only the fields kriss-welcome shows, to keep the package small."""
import json
import pathlib
import urllib.request

SRC = "https://raw.githubusercontent.com/AreWeAntiCheatYet/AreWeAntiCheatYet/master/games.json"
OUT = pathlib.Path(__file__).with_name("games.json")


def slim(g):
    d = {"name": g["name"], "slug": g["slug"], "status": g["status"], "anticheats": g["anticheats"]}
    if g.get("native"):
        d["native"] = True
    if g.get("notes"):
        d["note"] = g["notes"][0][0]
    if g.get("storeIds", {}).get("steam"):
        d["steam"] = g["storeIds"]["steam"]
    return d


if __name__ == "__main__":
    with urllib.request.urlopen(SRC, timeout=60) as r:
        games = sorted((slim(g) for g in json.load(r)), key=lambda d: d["name"].casefold())
    OUT.write_text("[\n" + ",\n".join(json.dumps(g, ensure_ascii=False) for g in games) + "\n]\n")
    print(f"{len(games)} games -> {OUT}")
