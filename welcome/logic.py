"""Pure logic for kriss-welcome, kept free of Qt so it can be tested anywhere."""
import html
import json
import os
import pathlib
import shutil
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


# --- Copy from Windows ---------------------------------------------------------------------
# Windows recovery partitions (GPT and MBR type) hold no user files.
WINDOWS_RE = {"de94bba4-06d1-4d40-a16a-bfd50179d6ac", "0x27"}
NOT_PEOPLE = {"all users", "default", "default user", "defaultuser0", "public", "wdagutilityaccount"}
FOLDERS = ("Desktop", "Documents", "Pictures", "Music", "Videos")
JUNK = {"desktop.ini", "thumbs.db"}
BROWSERS = {
    "Edge": "AppData/Local/Microsoft/Edge/User Data/Default/Bookmarks",
    "Chrome": "AppData/Local/Google/Chrome/User Data/Default/Bookmarks",
}


def windows_partitions(lsblk_json):
    """Partitions that may hold Windows, from `lsblk -J -b -o PATH,FSTYPE,LABEL,SIZE,MOUNTPOINT,PARTTYPE`.
    lsblk reads the udev database, so this needs no root. BitLocker volumes are listed so the
    page can explain why they are skipped."""
    out = []

    def walk(devs):
        for d in devs:
            fs = (d.get("fstype") or "").lower()
            if fs in ("ntfs", "bitlocker") and (d.get("parttype") or "").lower() not in WINDOWS_RE:
                out.append({"path": d["path"], "label": d.get("label") or "", "size": int(d.get("size") or 0),
                            "mountpoint": d.get("mountpoint") or "", "bitlocker": fs == "bitlocker"})
            walk(d.get("children") or [])

    try:
        walk(json.loads(lsblk_json).get("blockdevices") or [])
    except (ValueError, AttributeError):
        return []
    return out


def windows_users(root):
    """Names of the people with a folder in <root>/Users."""
    try:
        dirs = [p for p in (pathlib.Path(root) / "Users").iterdir() if p.is_dir() and not p.is_symlink()]
    except OSError:
        return []
    return sorted(p.name for p in dirs if p.name.casefold() not in NOT_PEOPLE)


def plan_copy(user_dir, dests):
    """(source, destination) folder pairs. dests maps a FOLDERS name to a folder in $HOME.
    OneDrive's folder backup moves Desktop, Documents and Pictures into OneDrive, so look there too."""
    user_dir = pathlib.Path(user_dir)
    return [(src, pathlib.Path(dst)) for name, dst in dests.items()
            for src in (user_dir / name, user_dir / "OneDrive" / name) if src.is_dir()]


def files_to_copy(pairs):
    """(source, destination, size) for each regular file. Links (Windows junctions such as
    "My Music") are not followed, and a file that already exists at home is never replaced."""
    out = []
    for src, dst in pairs:
        for root, _dirs, files in os.walk(src):
            for f in files:
                s = pathlib.Path(root) / f
                d = dst / s.relative_to(src)
                if f.casefold() in JUNK or s.is_symlink() or d.exists():
                    continue
                try:
                    out.append((s, d, s.stat().st_size))
                except OSError:
                    continue
    return out


def copy_files(items):
    """Copy (source, destination, size) items, yielding (bytes done, file name, ok) after each.
    Only reads the source; a half-written destination is removed."""
    done = 0
    for s, d, size in items:
        ok = True
        try:
            d.parent.mkdir(parents=True, exist_ok=True)
            with open(s, "rb") as fi, open(d, "xb") as fo:  # "x": never overwrite
                shutil.copyfileobj(fi, fo, 1 << 20)
            st = s.stat()
            os.utime(d, ns=(st.st_atime_ns, st.st_mtime_ns))  # keep photo and document dates
        except FileExistsError:
            ok = False
        except OSError:
            ok = False
            d.unlink(missing_ok=True)
        done += size
        yield done, s.name, ok


def bookmarks_html(chromium_json):
    """Edge or Chrome bookmarks as a Netscape bookmark file, which Firefox and every other
    browser can import. Returns "" when there are none."""
    try:
        roots = json.loads(chromium_json)["roots"]
    except (ValueError, KeyError, TypeError):
        return ""
    count = 0

    def node(n, pad):
        nonlocal count
        if n.get("type") == "url":
            count += 1
            return f'{pad}<DT><A HREF="{html.escape(n.get("url", ""))}">{html.escape(n.get("name", ""))}</A>\n'
        kids = "".join(node(c, pad + "    ") for c in n.get("children", []))
        return f"{pad}<DT><H3>{html.escape(n.get('name', ''))}</H3>\n{pad}<DL><p>\n{kids}{pad}</DL><p>\n" if kids else ""

    body = "".join(node(r, "    ") for r in roots.values() if isinstance(r, dict))
    if not count:
        return ""
    return ("<!DOCTYPE NETSCAPE-Bookmark-file-1>\n"
            '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">\n'
            f"<TITLE>Bookmarks</TITLE>\n<H1>Bookmarks</H1>\n<DL><p>\n{body}</DL><p>\n")


# --- Drivers and extras --------------------------------------------------------------------
# Fixed commands only: the page asks for an extra by id and never builds a command itself.
# ponytail: pkexec sh -c joins pacman and systemctl under one password prompt. Move these to a
# `kriss extras` command once tools/kriss has room for it.
EXTRAS = {
    "codecs": {"packages": ["gst-libav", "gst-plugins-good", "gst-plugins-bad", "gst-plugins-ugly", "ffmpeg"]},
    # ponytail: driverless (IPP Everywhere) printers only; add gutenprint/foomatic-db when people
    # bring older printers.
    "printers": {"packages": ["cups", "cups-pdf", "system-config-printer"], "enable": "cups.socket"},
    "gaming": {"packages": ["kriss-meta-gaming"]},
    "ollama": {"packages": ["ollama"], "enable": "ollama.service"},
    "ai-clis": {"packages": ["openai-codex", "gemini-cli"]},
    # Claude Code is not in the Arch repos; its official installer puts it in ~/.local/bin, no root.
    "claude-code": {"user": "curl -fsSL https://claude.ai/install.sh | bash", "binary": "claude"},
    # Pre-Turing NVIDIA GPUs (hwcheck's nvidia_legacy). kriss nvidia setup also adds the kernel
    # headers, the initramfs and command line changes and, on hybrid laptops, prime-run.
    "nvidia-legacy": {"root": ["kriss", "nvidia", "setup"], "packages": ["nvidia-580xx-dkms", "nvidia-580xx-utils"]},
}


def ollama_packages(gpus):
    """Ollama plus the GPU backend for this PC (from `kriss hwcheck`)."""
    for vendor, pkg in (("nvidia", "ollama-cuda"), ("amd", "ollama-rocm"), ("intel", "ollama-vulkan")):
        if vendor in gpus:
            return ["ollama", pkg]
    return ["ollama"]


def extra_packages(extra_id, gpus):
    return ollama_packages(gpus) if extra_id == "ollama" else EXTRAS[extra_id].get("packages", [])


def extra_command(extra_id, gpus):
    """The argv that installs one extra."""
    e = EXTRAS[extra_id]
    if "user" in e:
        return ["sh", "-c", e["user"]]
    if "root" in e:
        return ["pkexec", *e["root"]]
    script = 'pacman -S --needed --noconfirm "$@"'
    if "enable" in e:
        script += " && systemctl enable --now " + e["enable"]
    return ["pkexec", "sh", "-c", script, "sh", *extra_packages(extra_id, gpus)]


def extra_installed(extra_id, gpus):
    e = EXTRAS[extra_id]
    if "binary" in e:
        return bool(shutil.which(e["binary"]) or (pathlib.Path.home() / ".local/bin" / e["binary"]).exists())
    try:  # pacman -T prints what is missing and exits 127; 0 means all installed
        return subprocess.run(["pacman", "-T", *extra_packages(extra_id, gpus)], capture_output=True,
                              timeout=10).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


# --- Local AI models -----------------------------------------------------------------------
# Shown after Ollama is installed, so the user knows what runs well here before downloading.
# size_gb is the download from the Ollama library; need_mb adds room for the conversation and
# the runtime. ponytail: rough numbers for the default 4-bit builds; check them when the list
# changes, or read real sizes from the Ollama library once there is a reason to go online.
OLLAMA_MODELS = [
    {"name": "llama3.2:3b", "kind": "general", "size_gb": 2.0, "need_mb": 3584},
    {"name": "llama3.1:8b", "kind": "general", "size_gb": 4.9, "need_mb": 7168},
    {"name": "gemma3:12b", "kind": "general", "size_gb": 8.1, "need_mb": 10240},
    {"name": "gemma3:27b", "kind": "general", "size_gb": 17, "need_mb": 20480},
    {"name": "qwen2.5-coder:1.5b", "kind": "coding", "size_gb": 1.0, "need_mb": 2560},
    {"name": "qwen2.5-coder:7b", "kind": "coding", "size_gb": 4.7, "need_mb": 6656},
    {"name": "qwen2.5-coder:32b", "kind": "coding", "size_gb": 20, "need_mb": 23552},
]


def model_fits(hw):
    """Which OLLAMA_MODELS run well on this PC (from `kriss hwcheck`).
    fits: all of it sits in graphics memory or, without a graphics card, in RAM with 4 GB left
    for everything else. tight: it runs, but part of it moves to the processor (slower) or
    there is little RAM left for other apps. too_big: it will not run well."""
    # Under 2 GB is an APU's carve-out, not a graphics card worth sizing for.
    vram = hw.get("vram_mb", 0) if hw.get("vram_mb", 0) >= 2048 else 0
    ram = hw.get("ram_mb", 0)
    budget = vram or ram - 4096
    models = [{**m, "fit": "fits" if m["need_mb"] <= budget else "tight" if m["need_mb"] <= ram - 2048
               else "too_big"} for m in OLLAMA_MODELS]
    return {"gpu": bool(vram), "memory_mb": vram or ram, "models": models}


def ollama_names(ollama_list):
    """Model names from `ollama list` (a header row, then one model per line)."""
    return [line.split()[0] for line in ollama_list.splitlines()[1:] if line.strip()]


# --- Desktop layout ------------------------------------------------------------------------
# The shell's two layouts (see shell/qml/Desktop.qml): the taskbar, or the top bar and dock.
LAYOUTS = ("windows", "mac")


def shell_config():
    return pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or pathlib.Path.home() / ".config") / "kriss/shell.json"


def read_layout(path):
    try:
        layout = json.loads(pathlib.Path(path).read_text()).get("layout")
    except (OSError, ValueError, AttributeError):
        layout = None
    return layout if layout in LAYOUTS else "windows"


def write_layout(path, layout):
    """Set "layout" in shell.json and keep the rest, for when the shell is not running."""
    path = pathlib.Path(path)
    try:
        config = json.loads(path.read_text())
    except (OSError, ValueError):
        config = {}
    if not isinstance(config, dict):
        config = {}
    config["layout"] = layout
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(config, indent=4) + "\n")


# The look: the KrissOS Shell's colours (shell/qml/Theme.qml), made from theme/tokens.json.
def _rgb(c):
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, t):
    """Colour a moved t of the way to colour b, as #RRGGBB (theme/generate.py's mix)."""
    return "#" + "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(_rgb(a), _rgb(b)))


def palette(tokens, dark, accent=None):
    """The shell's surfaces as plain colours: the window, a raised card, the card under the
    pointer, hairlines, softened text, and the accent with the ink on it and as text
    (deepened on light so it keeps 4.5:1 on white). accent is the user's pick from shell.json."""
    t = tokens if dark else {**tokens, **{k[6:]: v for k, v in tokens.items() if k.startswith("light_")}}
    accent = accent if isinstance(accent, str) and len(accent) == 7 and accent.startswith("#") else t["accent"]
    try:
        r, g, b = _rgb(accent)
    except ValueError:
        accent = t["accent"]
        r, g, b = _rgb(accent)
    card = mix(t["surface"], t["fg"], 0.06) if dark else t["surface"]
    return {
        "dark": dark,
        "win": t["surface"] if dark else t["bg"],
        "card": card,
        "cardHover": mix(card, t["fg"], 0.12),
        "fg": t["fg"],
        "soft": mix(card, t["fg"], 0.66),
        "line": mix(card, t["fg"], 0.14),
        "accent": accent,
        "accentHover": mix(accent, "#FFFFFF", 0.15) if dark else mix(accent, "#000000", 0.1),
        "accentInk": "#000000" if 0.299 * r + 0.587 * g + 0.114 * b > 140 else "#FFFFFF",
        "accentText": accent if dark else mix(accent, t["fg"], 0.35),
        "red": t["color1"], "green": t["color2"], "amber": t["color3"],
        "sans": t["font_sans"], "mono": t["font_mono"],
    }


def read_accent(path):
    try:
        return json.loads(pathlib.Path(path).read_text()).get("accent")
    except (OSError, ValueError, AttributeError):
        return None
