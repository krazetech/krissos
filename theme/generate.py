#!/usr/bin/env python3
"""Render KrissOS themed files from tokens.json.

usage: generate.py TEMPLATE_DIR OUT_DIR
       generate.py --test

Every file under TEMPLATE_DIR is written to OUT_DIR at the same relative path
with {{name}} replaced by the token value. Colour tokens also give
{{name.hex}} (no '#') and {{name.rgbf}} ("r, g, b" as 0-1 floats, for Plymouth).
An unknown {{token}} is a KeyError, so a typo fails the build.

wallpaper.svg is rendered twice into usr/share/backgrounds/kriss/: kriss-dark.svg
from the tokens as they are, kriss-light.svg with every light_X token in place of X.
"""
import json
import pathlib
import re
import sys

TOKENS = pathlib.Path(__file__).with_name("tokens.json")
WALLPAPER = pathlib.Path(__file__).with_name("wallpaper.svg")


def variants(tokens):
    out = dict(tokens)
    for name, value in tokens.items():
        if re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
            out[name + ".hex"] = value[1:]
            out[name + ".rgbf"] = ", ".join(
                f"{int(value[i:i + 2], 16) / 255:.3f}" for i in (1, 3, 5))
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
    wp = dst / "usr/share/backgrounds/kriss"
    wp.mkdir(parents=True, exist_ok=True)
    for mode, t in (("dark", tokens), ("light", light(tokens))):
        (wp / f"kriss-{mode}.svg").write_text(render(WALLPAPER.read_text(), variants(t)))


def test():
    v = variants({"accent": "#29B2E8", "font": "Figtree"})
    assert render("{{accent}} {{accent.hex}} {{font}}", v) == "#29B2E8 29B2E8 Figtree"
    assert v["accent.rgbf"] == "0.161, 0.698, 0.910"
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
