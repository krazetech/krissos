"""Run: python store/test_store.py (no Qt). Checks the catalogue against a small AppStream file."""
import gzip
import json
import os
import pathlib
import subprocess
import sys
import tempfile

import logic

HERE = pathlib.Path(__file__).resolve().parent
XML = b"""<?xml version="1.0" encoding="UTF-8"?>
<components version="0.8" origin="flathub">
  <component type="desktop-application">
    <id>org.libreoffice.LibreOffice</id>
    <name>LibreOffice</name>
    <summary>The office suite</summary>
    <summary xml:lang="ms">Suite pejabat</summary>
    <description><p>Write  documents.</p><p xml:lang="ms">Tulis dokumen.</p><ul><li>Writer</li><li xml:lang="ms">Penulis</li></ul></description>
    <developer id="org.libreoffice"><name>The Document Foundation</name></developer>
    <icon type="cached" width="128" height="128">org.libreoffice.LibreOffice.png</icon>
    <icon type="remote">https://example.org/lo.png</icon>
    <categories><category>Office</category><category>WordProcessor</category></categories>
    <keywords><keyword>word</keyword><keyword>excel</keyword></keywords>
    <screenshots><screenshot type="default"><image type="thumbnail" width="224">https://e.org/t.png</image><image type="source">https://e.org/s.png</image></screenshot></screenshots>
    <bundle type="flatpak">app/org.libreoffice.LibreOffice/x86_64/stable</bundle>
  </component>
  <component type="desktop">
    <id>com.spotify.Client.desktop</id>
    <name>Spotify</name>
    <summary>Online music streaming service</summary>
    <developer_name>Spotify</developer_name>
    <categories><category>Audio</category><category>Music</category></categories>
    <bundle type="flatpak">app/com.spotify.Client/x86_64/stable</bundle>
  </component>
  <component type="desktop-application">
    <id>org.example.Office</id>
    <name>Tiny Office Helper</name>
    <summary>Helps</summary>
    <categories><category>Utility</category></categories>
    <bundle type="flatpak">app/org.example.Office/x86_64/stable</bundle>
  </component>
  <component type="runtime">
    <id>org.gnome.Platform</id>
    <name>GNOME runtime</name>
    <bundle type="flatpak">runtime/org.gnome.Platform/x86_64/47</bundle>
  </component>
</components>
"""


def flatpak_root(t):
    d = logic.appstream_dir(t)
    (d / "icons/128x128").mkdir(parents=True)
    (d / "icons/128x128/org.libreoffice.LibreOffice.png").write_bytes(b"png")
    (d / "appstream.xml.gz").write_bytes(gzip.compress(XML))
    return d


with tempfile.TemporaryDirectory() as t:
    d = flatpak_root(t)
    apps = logic.load_catalogue(t)
    ids = [a["id"] for a in apps]
    # The packs first, then the desktop apps by name; runtimes left out.
    assert ids[:len(logic.PACKS)] == [p["id"] for p in logic.PACKS], ids
    assert ids[len(logic.PACKS):] == ["org.libreoffice.LibreOffice", "com.spotify.Client", "org.example.Office"], ids
    lo = apps[len(logic.PACKS)]
    assert lo["icon"] == "file://" + str(d / "icons/128x128/org.libreoffice.LibreOffice.png"), lo["icon"]
    assert lo["shot"] == "https://e.org/s.png", lo["shot"]
    assert lo["desc"] == "Write documents.\n• Writer", lo["desc"]
    assert lo["dev"] == "The Document Foundation", lo["dev"]
    assert lo["cats"] == ["productivity"], lo["cats"]
    sp = next(a for a in apps if a["id"] == "com.spotify.Client")
    assert sp["cats"] == ["media"] and sp["dev"] == "Spotify" and sp["icon"] == "", sp
    # Bahasa Melayu where translated, English otherwise.
    ms = {a["id"]: a for a in logic.load_catalogue(t, "ms")}
    lo_ms = ms["org.libreoffice.LibreOffice"]
    assert lo_ms["summary"] == "Suite pejabat" and lo_ms["desc"] == "Tulis dokumen.\n• Penulis", lo_ms
    assert ms["com.spotify.Client"]["summary"] == "Online music streaming service"

    # Search: a word in the name, then inside it, then keywords and summaries; packs too.
    assert [a["id"] for a in logic.search(apps, "office")][:2] == ["org.example.Office", "org.libreoffice.LibreOffice"]
    assert [a["id"] for a in logic.search(apps, "excel")] == ["org.libreoffice.LibreOffice"]
    assert [a["id"] for a in logic.search(apps, "music")] == ["com.spotify.Client"]
    assert logic.search(apps, "steam")[0]["id"] == "kriss-meta-gaming"
    assert logic.search(apps, "  ") == []
    assert [a["id"] for a in logic.in_category(apps, "games")] == ["kriss-meta-gaming"]
    # Featured: the packs, then the Flathub picks that exist.
    assert [a["id"] for a in logic.featured(apps)] == ["kriss-meta-gaming", "kriss-meta-winapps",
                                                       "com.spotify.Client", "org.libreoffice.LibreOffice"]

    # Start's index, written by `kriss-store --write-index` without Qt.
    env = dict(os.environ, KRISS_STORE_FLATPAK=t, XDG_CACHE_HOME=t + "/cache", LANG="ms_MY.UTF-8")
    subprocess.run([sys.executable, "-B", str(HERE / "kriss_store.py"), "--write-index"], env=env, check=True)
    rows = json.loads(pathlib.Path(t, "cache/kriss/store.json").read_text())
    assert {"id": "com.spotify.Client", "name": "Spotify", "summary": "Online music streaming service",
            "icon": "", "keywords": ""} in rows, rows
    assert next(r for r in rows if r["id"] == "org.libreoffice.LibreOffice")["summary"] == "Suite pejabat"
    assert len(rows) == 3, rows  # no packs

# No AppStream yet (first boot, offline): just the packs.
with tempfile.TemporaryDirectory() as t:
    assert [a["id"] for a in logic.load_catalogue(t)] == [p["id"] for p in logic.PACKS]

assert logic.parse_checkupdates("firefox 131.0-1 -> 132.0-1\nlinux 6.12 -> 6.13\njunk\n") == [
    ("firefox", "132.0-1"), ("linux", "6.13")]
assert logic.parse_flatpak_ids("Application ID\ncom.spotify.Client\n\norg.gimp.GIMP\n") == ["com.spotify.Client", "org.gimp.GIMP"]
print("store ok")
