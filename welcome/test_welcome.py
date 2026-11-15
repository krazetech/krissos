"""Run: python welcome/test_welcome.py (needs bash; no Qt)."""
import json
import os
import pathlib
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

import logic

ROOT = pathlib.Path(__file__).resolve().parent


def hwcheck(ram_kb, flags, threads, kvm, vendors):
    with tempfile.TemporaryDirectory() as t:
        t = pathlib.Path(t)
        (t / "proc").mkdir()
        (t / "proc/meminfo").write_text(f"MemTotal:       {ram_kb} kB\nMemFree: 1 kB\n")
        (t / "proc/cpuinfo").write_text("".join(f"processor\t: {i}\nflags\t\t: fpu {flags} sse\n\n" for i in range(threads)))
        (t / "dev").mkdir()
        if kvm:
            (t / "dev/kvm").touch()
        for i, v in enumerate(vendors):
            d = t / f"sys/class/drm/card{i}/device"
            d.mkdir(parents=True)
            (d / "vendor").write_text(v + "\n")
        (t / "sys/class/drm").mkdir(parents=True, exist_ok=True)
        env = {"KRISS_PROC": t / "proc", "KRISS_SYS": t / "sys", "KRISS_DEV": t / "dev", "PATH": "/usr/bin:/bin"}
        out = subprocess.run([ROOT.parent / "tools/kriss", "hwcheck"], env={k: str(v) for k, v in env.items()},
                             capture_output=True, text=True, check=True).stdout
        return json.loads(out)


strong = hwcheck(32_000_000, "vmx", 12, True, ["0x10de", "0x8086"])
assert strong == {"ram_mb": 31250, "cores": 12, "virt": "vmx", "kvm": True, "gpus": ["intel", "nvidia"],
                  "winboat_ok": True, "reasons": []}, strong
weak = hwcheck(8_000_000, "", 2, False, [])
assert weak["winboat_ok"] is False and weak["reasons"] == ["ram", "virt", "kvm", "cores"], weak
assert weak["gpus"] == [] and weak["virt"] == ""
assert hwcheck(16_000_000, "svm", 8, True, ["0x1002"])["winboat_ok"] is True  # 16 GB AMD box

assert logic.parse_hwcheck("garbage")["winboat_ok"] is False
assert logic.read_hwcheck(("/nonexistent/kriss",))["reasons"] == ["unknown"]

games = json.loads((ROOT / "data/games.json").read_text())
hits = logic.search_games(games, "  fortnite ")
assert hits and hits[0]["name"].casefold().startswith("fortnite"), hits[:2]
assert logic.search_games(games, "") == []
assert all({"name", "slug", "status", "anticheats"} <= g.keys() for g in games)

apps = {a["id"]: a for a in json.loads((ROOT / "data/apps.json").read_text())}
assert 40 <= len(apps)
for a in apps.values():
    assert a["wine"] in ("yes", "partial", "no") and isinstance(a["winboat"], bool), a["id"]
    assert not a["native"] or a["alts"][0].get("flatpak"), a["id"]
    assert all(x.get("flatpak") or x.get("url") for x in a["alts"]), a["id"]

assert logic.answer(apps["discord"], False)["kind"] == "native"
assert logic.answer(apps["photoshop"], True)["kind"] == "winboat"
ps = logic.answer(apps["photoshop"], False)
assert ps["kind"] == "alternative" and ps["winboat_blocked"]
assert logic.answer(apps["notepadpp"], False) | {"alts": None} == {
    "kind": "alternative", "alts": None, "wine": "yes", "winboat_blocked": False, "web": ""}
assert logic.answer(apps["gdrive"], True)["kind"] == "web"
assert logic.answer({"native": False, "winboat": False, "alts": [], "wine": "yes"}, True)["kind"] == "wine"
assert logic.answer({"native": False, "winboat": False, "alts": [], "wine": "no"}, True)["kind"] == "none"

# Copy from Windows
lsblk = json.dumps({"blockdevices": [{"path": "/dev/nvme0n1", "fstype": None, "children": [
    {"path": "/dev/nvme0n1p1", "fstype": "vfat", "parttype": "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"},
    {"path": "/dev/nvme0n1p3", "fstype": "ntfs", "label": "OS", "size": 500107862016, "mountpoint": None,
     "parttype": "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7"},
    {"path": "/dev/nvme0n1p4", "fstype": "ntfs", "parttype": "de94bba4-06d1-4d40-a16a-bfd50179d6ac"},
    {"path": "/dev/nvme0n1p5", "fstype": "BitLocker", "size": "1000", "parttype": "ebd0a0a2-b9e5-4433-87c0-68b6b72699c7"},
]}]})
parts = logic.windows_partitions(lsblk)
assert [(x["path"], x["bitlocker"]) for x in parts] == [("/dev/nvme0n1p3", False), ("/dev/nvme0n1p5", True)], parts
assert parts[0] == {"path": "/dev/nvme0n1p3", "label": "OS", "size": 500107862016, "mountpoint": "", "bitlocker": False}
assert logic.windows_partitions("") == [] and logic.windows_partitions("{}") == []

with tempfile.TemporaryDirectory() as t:
    t = pathlib.Path(t)
    win, home = t / "win", t / "home"
    for d in ("Users/Public", "Users/Default", "Users/Aina/Documents/Kerja", "Users/Aina/Pictures",
              "Users/Aina/OneDrive/Desktop", "Users/Aina/Music"):
        (win / d).mkdir(parents=True)
    user = win / "Users/Aina"
    (user / "Documents/Kerja/cv.docx").write_bytes(b"cv")
    (user / "Documents/desktop.ini").write_text("junk")
    (user / "Documents/My Music").symlink_to(user / "Music")  # a Windows junction
    (user / "Pictures/raya.jpg").write_bytes(b"x" * 5000)
    os.utime(user / "Pictures/raya.jpg", (1_600_000_000, 1_600_000_000))
    (user / "OneDrive/Desktop/note.txt").write_text("from OneDrive")
    (user / "Music/song.mp3").write_bytes(b"song")
    (user / "Music/locked.mp3").write_bytes(b"x")
    (user / "Music/locked.mp3").chmod(0)  # unreadable, like an online-only OneDrive file
    (home / "Pictures").mkdir(parents=True)
    (home / "Pictures/raya.jpg").write_bytes(b"mine")  # already here: must be kept
    assert logic.windows_users(win) == ["Aina"]
    assert logic.windows_users(t / "nowhere") == []

    dests = {f: home / f for f in logic.FOLDERS}
    pairs = logic.plan_copy(user, dests)
    assert (user / "OneDrive/Desktop", home / "Desktop") in pairs and len(pairs) == 4, pairs
    items = logic.files_to_copy(pairs)
    names = sorted(s.name for s, _d, _n in items)
    assert names == ["cv.docx", "locked.mp3", "note.txt", "song.mp3"], names
    steps = list(logic.copy_files(items))
    assert steps[-1][0] == sum(n for _s, _d, n in items)
    failed = [name for _done, name, ok in steps if not ok]
    assert failed == ([] if os.geteuid() == 0 else ["locked.mp3"]), failed
    assert (home / "Documents/Kerja/cv.docx").read_bytes() == b"cv"
    assert (home / "Desktop/note.txt").read_text() == "from OneDrive"
    assert (home / "Pictures/raya.jpg").read_bytes() == b"mine"
    assert not (home / "Documents/My Music").exists() and not (home / "Documents/desktop.ini").exists()
    if os.geteuid():
        assert not (home / "Music/locked.mp3").exists()  # no half-copied file left behind
    # Windows itself is untouched.
    assert sorted(p.name for p in (user / "Documents").iterdir()) == ["Kerja", "My Music", "desktop.ini"]
    (user / "Music/locked.mp3").chmod(0o644)

    # Copy dates are kept
    (home / "Pictures/raya.jpg").unlink()
    list(logic.copy_files(logic.files_to_copy([(user / "Pictures", home / "Pictures")])))
    assert (home / "Pictures/raya.jpg").stat().st_mtime == 1_600_000_000

edge = {"roots": {
    "bookmark_bar": {"type": "folder", "name": "Bookmarks bar", "children": [
        {"type": "url", "name": "MySejahtera & <co>", "url": "https://mysejahtera.moh.gov.my/?a=1&b=2"},
        {"type": "folder", "name": "Empty", "children": []}]},
    "other": {"type": "folder", "name": "Other bookmarks", "children": []},
    "sync_transaction_version": "1"}}
page = logic.bookmarks_html(json.dumps(edge))
assert page.startswith("<!DOCTYPE NETSCAPE-Bookmark-file-1>"), page
assert '<A HREF="https://mysejahtera.moh.gov.my/?a=1&amp;b=2">MySejahtera &amp; &lt;co&gt;</A>' in page, page
assert "<H3>Bookmarks bar</H3>" in page and "Empty" not in page and "Other bookmarks" not in page
assert logic.bookmarks_html('{"roots": {"other": {"children": []}}}') == ""
assert logic.bookmarks_html("not json") == ""

# Drivers and extras
assert logic.ollama_packages(["intel", "nvidia"]) == ["ollama", "ollama-cuda"]
assert logic.ollama_packages(["amd"]) == ["ollama", "ollama-rocm"]
assert logic.ollama_packages([]) == ["ollama"]
assert logic.extra_command("gaming", []) == [
    "pkexec", "sh", "-c", 'pacman -S --needed --noconfirm "$@"', "sh", "kriss-meta-gaming"]
cmd = logic.extra_command("ollama", ["nvidia"])
assert cmd[3].endswith("systemctl enable --now ollama.service") and cmd[-2:] == ["ollama", "ollama-cuda"], cmd
assert logic.extra_command("claude-code", [])[0] == "sh"  # per-user install, no root
assert all(logic.extra_command(e, ["amd"]) for e in logic.EXTRAS)
qml = (ROOT / "qml/ExtrasPage.qml").read_text()
assert set(re.findall(r'\{ id: "([a-z-]+)"', qml)) - {"antigravity"} == set(logic.EXTRAS)

# kriss update refuses to run without root (it needs pkexec).
if os.geteuid():
    r = subprocess.run([ROOT.parent / "tools/kriss", "update"], capture_output=True, text=True)
    assert r.returncode == 2 and "pkexec kriss update" in r.stderr, r

# kriss-update-notify, with stand-ins for the tools it calls.
def notify(updates, click, pkexec_code, lang="en_US.UTF-8", err=""):
    with tempfile.TemporaryDirectory() as t:
        t = pathlib.Path(t)
        stubs = {"checkupdates": f"printf '%s' '{updates}'",
                 "notify-send": f'echo "notify $*" >> {t}/log; case "$*" in *--wait*) echo {click};; esac',
                 "pkexec": f'echo "pkexec $*" >> {t}/log; echo "{err}" >&2; exit {pkexec_code}'}
        for name, body in stubs.items():
            (t / name).write_text(f"#!/bin/sh\n{body}\n")
            (t / name).chmod(0o755)
        env = {"PATH": f"{t}:/usr/bin:/bin", "LANG": lang}
        subprocess.run([ROOT.parent / "tools/kriss-update-notify"], env=env, check=True)
        return (t / "log").read_text() if (t / "log").exists() else ""

assert notify("", "update", 0) == ""  # nothing to update: stay quiet
log = notify("linux 1 -> 2\nmesa 1 -> 2\n", "update", 0)
assert "--action=update=Update Updates available 2 updates are ready to install." in log, log
assert "pkexec kriss update" in log and "KrissOS is up to date" in log, log
log = notify("a\n", "", 0)
assert "pkexec" not in log, log  # dismissed: no update
assert "Kemas kini tersedia" in notify("a\n", "", 0, "ms_MY.UTF-8")
assert "did not finish" in notify("a\n", "update", 1)
assert "did not finish" not in notify("a\n", "update", 126)  # password prompt cancelled
assert "did not finish" not in notify("a\n", "update", 127)  # cancelled in the KDE agent
assert "did not finish" in notify("a\n", "update", 127, err="Error creating textual authentication agent")
assert "1 update is ready to install." in notify("a\n", "", 0)

# Every qsTr string has a Bahasa Melayu translation.
ts = ET.parse(ROOT / "i18n/kriss-welcome_ms.ts")
have = {(c.findtext("name"), m.findtext("source")) for c in ts.iter("context") for m in c.iter("message")
        if (m.findtext("translation") or "").strip()}
for f in (ROOT / "qml").glob("*.qml"):
    for m in re.finditer(r'qsTr\("((?:[^"\\]|\\.)*)"\)', f.read_text()):
        assert (f.stem, json.loads(f'"{m.group(1)}"')) in have, (f.name, m.group(1))
print("ok")
