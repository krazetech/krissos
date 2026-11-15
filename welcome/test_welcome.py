"""Run: python welcome/test_welcome.py (needs bash; no Qt)."""
import json
import pathlib
import subprocess
import tempfile

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
print("ok")
