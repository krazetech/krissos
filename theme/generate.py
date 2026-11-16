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
