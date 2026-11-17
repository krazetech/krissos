#!/usr/bin/env python3
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


def render(text, values):
    return re.sub(r"\{\{([\w.]+)\}\}", lambda m: values[m.group(1)], text)


def main(src, dst):
    tokens = json.loads(TOKENS.read_text())
    values = variants(tokens)
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
    for mode, t in (("dark", tokens), ("light", light(tokens))):
        out = render(WALLPAPER.read_text(), {**variants(t), "keris": keris})
        (wp / f"kriss-{mode}.svg").write_text(out)
    plymouth(dst / "usr/share/plymouth/themes/kriss", values, keris)


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
    json.loads(TOKENS.read_text())
    print("ok")


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        test()
    elif len(sys.argv) == 3:
        main(*sys.argv[1:])
    else:
        sys.exit(__doc__)
