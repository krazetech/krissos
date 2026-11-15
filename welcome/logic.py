"""Pure logic for kriss-welcome, kept free of Qt so it can be tested anywhere."""
import json
import subprocess

# Shown when `kriss hwcheck` is missing or fails: assume the PC cannot run WinBoat.
NO_HW = {"ram_mb": 0, "cores": 0, "virt": "", "kvm": False, "gpus": [], "winboat_ok": False,
         "reasons": ["unknown"]}


def parse_hwcheck(text):
    try:
        hw = json.loads(text)
    except ValueError:
        return dict(NO_HW)
    return hw if isinstance(hw, dict) and "winboat_ok" in hw else dict(NO_HW)


def read_hwcheck(cmd=("kriss", "hwcheck")):
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=10, check=True).stdout
    except (OSError, subprocess.SubprocessError):
        return dict(NO_HW)
    return parse_hwcheck(out)


def search_games(games, query, limit=50):
    """Case-insensitive substring search; names that start with the query come first."""
    q = query.strip().casefold()
    if not q:
        return []
    hits = [g for g in games if q in g["name"].casefold()]
    hits.sort(key=lambda g: not g["name"].casefold().startswith(q))
    return hits[:limit]


def answer(app, winboat_ok):
    """The one recommendation for a Windows app on this PC.

    kind: native (the same app exists for Linux), winboat (run the real Windows app in a VM),
    alternative (a Linux app does the same job), wine (run it with Wine), web (use the browser),
    none. The UI also shows the other options it returns.
    """
    if app["native"]:
        kind = "native"
    elif app["winboat"] and winboat_ok:
        kind = "winboat"
    elif app["alts"]:
        kind = "alternative"
    elif app["wine"] in ("yes", "partial"):
        kind = "wine"
    elif app.get("web"):
        kind = "web"
    else:
        kind = "none"
    return {
        "kind": kind,
        "alts": app["alts"],
        "wine": app["wine"] if kind != "native" else "no",
        # WinBoat would help, but this PC cannot run it well.
        "winboat_blocked": app["winboat"] and not winboat_ok and not app["native"],
        "web": app.get("web", ""),
    }
