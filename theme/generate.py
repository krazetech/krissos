#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Kraze Tech
"""Render KrissOS themed files from tokens.json.

usage: generate.py TEMPLATE_DIR OUT_DIR
       generate.py --test

Every file under TEMPLATE_DIR is written to OUT_DIR at the same relative path
with {{name}} replaced by the token value. Colour tokens also give
{{name.hex}} (no '#'), {{name.rgb}} ("r,g,b" decimal, for KDE) and
{{name.rgbf}} ("r, g, b" as 0-1 floats, for Plymouth) and {{name.ansi}}
("38;2;r;g;b", a 24-bit foreground SGR code for prompts, /etc/issue and fastfetch).
An unknown {{token}} is a KeyError, so a typo fails the build.

When TEMPLATE_DIR is theme/templates (kriss-theme), wallpaper.svg is also
rendered twice into usr/share/backgrounds/kriss/: kriss-dark.svg
from the tokens as they are, kriss-light.svg with every light_X token in place of X.
{{keris}} in it is the emblem's keris path with no fill, so the wallpaper colours it.
It is rendered four more times for the time-of-day wallpaper, kriss-dawn/day/dusk/night.svg:
the same scene under a sky and sun mixed from the tokens (see times()).
ponytail: the shell's time-of-day wallpaper is now the Sungai Petani photo pair, so nothing
reads these four; drop them (and times()) unless an abstract Dynamic option comes back.
"""
import json
import pathlib
import re
import sys

TOKENS = pathlib.Path(__file__).with_name("tokens.json")
WALLPAPER = pathlib.Path(__file__).with_name("wallpaper.svg")
LOGO = pathlib.Path(__file__).parent / "templates/usr/share/pixmaps/krissos.svg"


def variants(tokens):
    out = dict(tokens)
    for name, value in tokens.items():
        if re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
            out[name + ".hex"] = value[1:]
            out[name + ".rgb"] = ",".join(str(int(value[i:i + 2], 16)) for i in (1, 3, 5))
            out[name + ".ansi"] = "38;2;" + out[name + ".rgb"].replace(",", ";")
            out[name + ".rgbf"] = ", ".join(
                f"{int(value[i:i + 2], 16) / 255:.3f}" for i in (1, 3, 5))
            # One channel at a time ({{accent.rf}}), for formats that name each field.
            for ch, i in zip("rgb", (1, 3, 5)):
                out[f"{name}.{ch}f"] = f"{int(value[i:i + 2], 16) / 255:.3f}"
    return out


def light(tokens):
    return {**tokens, **{k[6:]: v for k, v in tokens.items() if k.startswith("light_")}}


def mix(a, b, t):
    """Colour a moved t of the way to colour b, as #RRGGBB."""
    ca, cb = (tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in (a, b))
    return "#" + "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(ca, cb))


# No sky or sun: the plain dark and light wallpapers.
CLEAR = {"sky_top": "#000000", "sky_bottom": "#000000", "sky_opacity": "0",
         "sun": "#000000", "sun_opacity": "0", "sun_x": "0", "sun_y": "0"}


def times(t):
    """The lighting for each time of day: a sky (top and horizon) mixed from the dark
    background and a palette colour, and a sun, low on the left at dawn, high at noon and
    low on the right at dusk. Night is the dark wallpaper. Kept dark enough everywhere for
    the lock screen's light text."""
    bg = t["bg"]
    return {
        "dawn": {"sky_top": mix(bg, t["color13"], 0.22), "sky_bottom": mix(bg, t["color9"], 0.42),
                 "sky_opacity": "1", "sun": mix(t["color11"], t["color9"], 0.5), "sun_opacity": "0.36", "sun_x": "700", "sun_y": "1550"},
        "day": {"sky_top": mix(bg, t["color4"], 0.48), "sky_bottom": mix(bg, t["color14"], 0.40),
                "sky_opacity": "1", "sun": t["color15"], "sun_opacity": "0.30", "sun_x": "2900", "sun_y": "120"},
        "dusk": {"sky_top": mix(bg, t["color5"], 0.24), "sky_bottom": mix(bg, t["color1"], 0.40),
                 "sky_opacity": "1", "sun": t["color3"], "sun_opacity": "0.40", "sun_x": "3150", "sun_y": "1500"},
        "night": CLEAR,
    }


def ui(t, dark):
    """The shell's surfaces (shell/qml/Theme.qml) as plain colours, for apps that cannot run
    its JavaScript: the window, a raised card, a card under the pointer, secondary text and
    the accent as text (deepened on light so it keeps 4.5:1 on white)."""
    win = t["surface"] if dark else t["bg"]
    card = mix(t["surface"], t["fg"], 0.06) if dark else t["surface"]
    return {"ui_win": win, "ui_card": card, "ui_hover": mix(card, t["fg"], 0.12),
            "ui_line": mix(card, t["fg"], 0.14), "ui_soft": mix(card, t["fg"], 0.66),
            "ui_accent_text": t["accent"] if dark else mix(t["accent"], t["fg"], 0.35),
            "ui_scheme": "dark" if dark else "light"}


def render(text, values):
    return re.sub(r"\{\{([\w.]+)\}\}", lambda m: values[m.group(1)], text)


def main(src, dst):
    tokens = json.loads(TOKENS.read_text())
    values = variants({**tokens, **ui(tokens, True)})
    src, dst = pathlib.Path(src), pathlib.Path(dst)
    for f in sorted(src.rglob("*")):
        if f.is_file():
            out = dst / f.relative_to(src)
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(render(f.read_text(), values))
            out.chmod(f.stat().st_mode & 0o777)  # keep the exec bit on scripts
    # Only kriss-theme owns the wallpapers; kriss-settings reuses this script too.
    if src.resolve() != LOGO.parents[3].resolve():
        return
    wp = dst / "usr/share/backgrounds/kriss"
    wp.mkdir(parents=True, exist_ok=True)
    # Inlined, not <image>: Qt's SVG renderer cannot load an external or nested SVG.
    keris = re.sub(r' fill="[^"]*"', "", re.search(r"<path [^>]*/>", LOGO.read_text()).group(0))
    for mode, t, sky in (("dark", tokens, CLEAR), ("light", light(tokens), CLEAR),
                         *((n, tokens, v) for n, v in times(tokens).items())):
        out = render(WALLPAPER.read_text(), {**variants(t), **sky, "keris": keris})
        (wp / f"kriss-{mode}.svg").write_text(out)
    plymouth(dst / "usr/share/plymouth/themes/kriss", values, keris)
    # The installer's branding again in light colours. kriss-install puts this tree first in
    # XDG_DATA_DIRS (calamares -X) when the live session is light: Calamares loads one
    # stylesheet.qss and cannot switch it.
    lt = light(tokens)
    lvals = variants({**lt, **ui(lt, False)})
    branding = "usr/share/calamares/branding/krissos"
    for f in sorted((src / branding).rglob("*")):
        if f.is_file():
            out = dst / "usr/share/kriss-theme/calamares-light/calamares/branding/krissos" / f.relative_to(src / branding)
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(render(f.read_text(), lvals))
    qt6 = src / "usr/share/qt6ct/colors/kriss.conf"
    if qt6.is_file():
        (dst / "usr/share/qt6ct/colors/kriss-light.conf").write_text(render(qt6.read_text(), lvals))


PLYMOUTH_SIZES = (256, 512)  # the script picks the smallest one at least as big as the logo
GLOW = 2.6  # the glow image is this many logo widths across; kriss.script and greeter.qml use it


def plymouth(out, values, keris):
    """The boot splash layers, as SVG; the kriss-theme build turns each into a PNG.

    logo (the disc with the keris hilt) and glow (a soft Sky Cyan halo behind it, GLOW
    times as wide), each at every PLYMOUTH_SIZES; plus the password field and its bullet.
    The login screen (shell/qml/greeter.qml) draws the same logo and glow to take over.
    """
    disc = f'<circle cx="284.5" cy="284.5" r="284.5" fill="{values["accent"]}"/>'
    hilt = keris.replace("<path ", f'<path fill="{values["bg"]}" ', 1)
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="{0}" height="{0}" viewBox="0 0 569 569">{1}</svg>'
    halo = (f'<defs><radialGradient id="g"><stop offset="0" stop-color="{values["accent"]}" stop-opacity="0.5"/>'
            f'<stop offset="0.4" stop-color="{values["accent"]}" stop-opacity="0.16"/>'
            f'<stop offset="0.7" stop-color="{values["accent"]}" stop-opacity="0"/></radialGradient></defs>'
            '<rect width="569" height="569" fill="url(#g)"/>')
    for size in PLYMOUTH_SIZES:
        (out / f"logo-{size}.svg").write_text(svg.format(size, disc + hilt))
        (out / f"glow-{size}.svg").write_text(svg.format(round(size * GLOW), halo))
    # 2x the size the script shows them at 1080p, so they only ever scale down.
    (out / "field.svg").write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="88">'
        f'<rect x="1" y="1" width="638" height="86" rx="43" fill="{values["surface"]}" '
        f'stroke="{values["muted"]}" stroke-opacity="0.35" stroke-width="2"/></svg>')
    (out / "bullet.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">'
        f'<circle cx="12" cy="12" r="12" fill="{values["accent"]}"/></svg>')


def test():
    v = variants({"accent": "#29B2E8", "font": "Figtree"})
    assert render("{{accent}} {{accent.hex}} {{font}}", v) == "#29B2E8 29B2E8 Figtree"
    assert v["accent.rgb"] == "41,178,232"
    assert v["accent.rgbf"] == "0.161, 0.698, 0.910"
    assert v["accent.ansi"] == "38;2;41;178;232"
    assert (v["accent.rf"], v["accent.bf"]) == ("0.161", "0.910")
    assert "font.hex" not in v
    assert light({"bg": "#000000", "light_bg": "#FFFFFF"})["bg"] == "#FFFFFF"
    assert mix("#000000", "#FF8000", 0.5) == "#804000"
    t = json.loads(TOKENS.read_text())
    assert ui(t, True)["ui_win"] == t["surface"] and ui(light(t), False)["ui_card"] == t["light_surface"]
    assert set(times(json.loads(TOKENS.read_text()))) == {"dawn", "day", "dusk", "night"}
    print("ok")


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        test()
    elif len(sys.argv) == 3:
        main(*sys.argv[1:])
    else:
        sys.exit(__doc__)
