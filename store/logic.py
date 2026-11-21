# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Kraze Tech
"""The Store's catalogue, without Qt: Flathub's AppStream (which Flatpak keeps on disk) plus
the KrissOS packs, the Store's categories, search, and the index Start searches."""
import gzip
import json
import os
import pathlib
import re
import xml.etree.ElementTree as ET

FLATPAK = pathlib.Path("/var/lib/flatpak")
XML_LANG = "{http://www.w3.org/XML/1998/namespace}lang"

# The Store's categories, Windows Store style, from freedesktop main and extra categories.
# An app is in every category one of its own maps to.
CATEGORIES = {
    "productivity": ("Office", "Finance", "ProjectManagement", "WordProcessor", "Spreadsheet"),
    "creativity": ("Graphics", "2DGraphics", "3DGraphics", "Photography", "VectorGraphics", "AudioVideoEditing"),
    "games": ("Game",),
    "media": ("AudioVideo", "Audio", "Video", "Music", "Player"),
    "internet": ("Network", "WebBrowser", "Chat", "Email", "InstantMessaging"),
    "development": ("Development", "IDE"),
    "education": ("Education", "Science"),
    "utilities": ("Utility", "System", "Settings", "FileTools"),
}

# KrissOS packs: [kriss] metapackages, installed with pacman (snap-pac snapshots each run).
PACKS = [
    {"id": "kriss-meta-gaming", "kind": "pacman", "name": "KrissOS Gaming Pack", "icon": "input-gaming",
     "summary": "Steam, GameMode, Gamescope and MangoHud, with the Vulkan drivers",
     "desc": "What you need to play Windows games on KrissOS: Steam (with Proton), GameMode, Gamescope, the MangoHud overlay and the Vulkan drivers. Check your games' anti-cheat in KrissOS Welcome first.",
     "cats": ["games"], "dev": "KrissOS",
     "summary_ms": "Steam, GameMode, Gamescope dan MangoHud, bersama pemacu Vulkan",
     "desc_ms": "Apa yang anda perlukan untuk bermain permainan Windows di KrissOS: Steam (dengan Proton), GameMode, Gamescope, lapisan MangoHud dan pemacu Vulkan. Semak anti-tipu permainan anda dalam KrissOS Welcome dahulu."},
    {"id": "kriss-meta-winapps", "kind": "pacman", "name": "Windows Apps (WinBoat)", "icon": "computer",
     "summary": "Run real Windows apps in a Windows virtual machine",
     "desc": "WinBoat runs Windows in the background and shows its apps as normal windows. Needs about 16 GB of RAM and CPU virtualisation turned on. After installing, run 'kriss winapps setup' once.",
     "cats": ["productivity", "utilities"], "dev": "KrissOS",
     "summary_ms": "Jalankan aplikasi Windows sebenar dalam mesin maya Windows",
     "desc_ms": "WinBoat menjalankan Windows di latar belakang dan memaparkan aplikasinya sebagai tetingkap biasa. Memerlukan kira-kira 16 GB RAM dan virtualisasi CPU dihidupkan. Selepas memasang, jalankan 'kriss winapps setup' sekali."},
    # Not a package: `kriss winapps office` downloads Office from Microsoft into WinBoat's
    # Windows. Installed means its Start entries exist.
    {"id": "microsoft-office", "kind": "winapps", "name": "Microsoft Office (Word, Excel, PowerPoint)",
     "icon": "x-office-document", "summary": "The real Word, Excel and PowerPoint, in WinBoat, with your own licence",
     "desc": "Downloads Microsoft's Office installer from Microsoft (about 3 GB) and installs Word, Excel and PowerPoint in WinBoat's Windows. They then open from Start and open your .docx, .xlsx and .pptx files. Needs the internet, WinBoat set up first ('kriss winapps setup'), and your own Microsoft 365 subscription or product key: sign in or enter the key when Word first opens. KrissOS includes no Office files.",
     "summary_ms": "Word, Excel dan PowerPoint sebenar, dalam WinBoat, dengan lesen anda sendiri",
     "desc_ms": "Memuat turun pemasang Office terus daripada Microsoft (kira-kira 3 GB) dan memasang Word, Excel dan PowerPoint dalam Windows WinBoat. Selepas itu, aplikasi ini dibuka dari Start dan membuka fail .docx, .xlsx dan .pptx anda. Memerlukan internet, WinBoat yang telah disediakan ('kriss winapps setup') dan langganan Microsoft 365 atau kunci produk anda sendiri: log masuk atau masukkan kunci apabila Word dibuka kali pertama. KrissOS tidak menyertakan sebarang fail Office.",
     "cats": ["productivity"], "dev": "Microsoft"},
]

# Home's featured row, Flathub ids, after the packs.
FEATURED = ["org.mozilla.firefox", "com.google.Chrome", "com.discordapp.Discord", "com.spotify.Client",
            "com.valvesoftware.Steam", "org.libreoffice.LibreOffice", "com.obsproject.Studio",
            "org.videolan.VLC", "org.gimp.GIMP", "com.visualstudio.code", "org.telegram.desktop",
            "org.kde.kdenlive"]


def appstream_dir(root=FLATPAK, arch=None):
    return pathlib.Path(root) / "appstream/flathub" / (arch or os.uname().machine) / "active"


def _text(el, tag, lang):
    """The child's text in lang if the file has it, else the untranslated one."""
    best = None
    for c in el.findall(tag):
        l = c.get(XML_LANG)
        if l == lang:
            return (c.text or "").strip()
        if l is None and best is None:
            best = (c.text or "").strip()
    return best or ""


def _description(el, lang):
    """Plain paragraphs and bullets, in lang if translated. Flathub gives each language its own
    <description xml:lang>; older files mark the paragraphs inside one <description>."""
    ds = el.findall("description")
    d = next((d for d in ds if d.get(XML_LANG) == lang), None) or next((d for d in ds if d.get(XML_LANG) is None), None)
    if d is None:
        return ""
    out = []
    for c in d:
        l = c.get(XML_LANG)
        if l not in (None, lang):
            continue
        if c.tag == "p":
            out.append(("", l, " ".join("".join(c.itertext()).split())))
        elif c.tag in ("ul", "ol"):
            out += [("• ", li.get(XML_LANG, l), " ".join("".join(li.itertext()).split()))
                    for li in c if li.get(XML_LANG) in (None, lang)]
    # Translated paragraphs when there are any, else the English ones.
    keep = lang if any(l == lang for _b, l, _t in out) else None
    return "\n".join(b + t for b, l, t in out if l == keep and t)


def _store_cats(own):
    own = set(own)
    return [k for k, fd in CATEGORIES.items() if own & set(fd)]


def parse_appstream(xml_bytes, icons_dir, lang="en"):
    """Desktop apps from Flathub's appstream.xml, as dicts the QML shows."""
    apps = []
    root = ET.fromstring(xml_bytes)
    for c in root.iter("component"):
        if c.get("type") not in ("desktop", "desktop-application"):
            continue
        bundle = c.find("bundle")
        ref = bundle.text if bundle is not None and bundle.text else ""
        if not ref.startswith("app/"):
            continue
        app_id = ref.split("/")[1]
        icon = ""
        for i in c.findall("icon"):
            if i.get("type") == "cached" and i.text:
                for size in ("128x128", "64x64"):
                    p = pathlib.Path(icons_dir) / size / i.text
                    if p.exists():
                        icon = "file://" + str(p)
                        break
            if icon:
                break
        shot = ""
        for s in c.iter("screenshot"):
            imgs = s.findall("image")
            src = [i for i in imgs if i.get("type") == "source"] or imgs
            if src and src[0].text:
                shot = src[0].text.strip()
                break
        dev = c.find("developer")
        apps.append({
            "id": app_id, "kind": "flatpak",
            "name": _text(c, "name", lang) or app_id,
            "summary": _text(c, "summary", lang),
            "desc": _description(c, lang),
            "cats": _store_cats(x.text for x in c.iter("category") if x.text),
            "icon": icon, "shot": shot,
            "dev": _text(dev, "name", lang) if dev is not None else _text(c, "developer_name", lang),
            "keywords": " ".join(k.text for k in c.iter("keyword") if k.text).lower(),
        })
    return apps


def load_catalogue(root=FLATPAK, lang="en"):
    """The packs plus every Flathub app; just the packs when Flatpak has no AppStream yet."""
    d = appstream_dir(root)
    for name in ("appstream.xml.gz", "appstream.xml"):
        p = d / name
        if p.exists():
            data = p.read_bytes()
            if name.endswith(".gz"):
                data = gzip.decompress(data)
            apps = parse_appstream(data, d / "icons", lang)
            break
    else:
        apps = []
    apps.sort(key=lambda a: a["name"].lower())
    return [pack(p, lang) for p in PACKS] + apps


def pack(p, lang="en"):
    """A pack as the Store shows it, in Malay when there is a Malay text."""
    p = dict(p, shot="", keywords="")
    for k in ("summary", "desc"):
        p[k] = p.pop(k + "_ms") if lang == "ms" and k + "_ms" in p else p[k]
        p.pop(k + "_ms", None)
    return p


def search(apps, query, limit=60):
    """Name matches first (whole name, then its start, then a word start), then the rest."""
    q = query.strip().lower()
    if not q:
        return []
    word = re.compile(r"\b" + re.escape(q))
    scored = []
    for a in apps:
        n = a["name"].lower()
        if n == q:
            s = 0
        elif n.startswith(q):
            s = 1
        elif word.search(n):
            s = 2
        elif q in n or q == a["id"].lower():
            s = 3
        elif q in a["keywords"] or word.search(a["summary"].lower()):
            s = 4
        else:
            continue
        scored.append((s, a["name"].lower(), a))
    return [a for _s, _n, a in sorted(scored, key=lambda x: x[:2])][:limit]


def featured(apps):
    by_id = {a["id"]: a for a in apps}
    return [by_id[i] for i in [p["id"] for p in PACKS] + FEATURED if i in by_id]


def in_category(apps, cat):
    return [a for a in apps if cat in a["cats"]]


def parse_flatpak_ids(text):
    """`flatpak list --app --columns=application` (or remote-ls) output, one id a line."""
    return [l.strip() for l in text.splitlines() if l.strip() and not l.startswith("Application")]


def parse_checkupdates(text):
    """checkupdates lines, "name old -> new", as (name, new) pairs."""
    out = []
    for l in text.splitlines():
        f = l.split()
        if len(f) == 4 and f[2] == "->":
            out.append((f[0], f[3]))
    return out


def index_rows(apps):
    """What Start searches for "Get X from the Store". Flathub apps only: Start hides the ones
    that are installed by their desktop file id, which packs do not have."""
    return [{"id": a["id"], "name": a["name"], "summary": a["summary"], "icon": a["icon"],
             "keywords": a["keywords"]} for a in apps if a["kind"] == "flatpak"]


def write_index(apps, path):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(index_rows(apps), ensure_ascii=False, separators=(",", ":")))
    tmp.replace(path)
