#!/usr/bin/env python3
"""Inject the Rojo-built cheat LocalScript into the user's place .rbxlx.

We do a targeted XML insertion (instead of a full parse) because the place
uses newer Roblox property types that generic rbx-dom parsers reject.

    usage: merge.py <place.rbxlx> <cheat.rbxmx> <out.rbxlx>
"""
import re
import sys


def extract_localscript_item(rbxmx_text: str) -> str:
    """Pull the <Item class="LocalScript">...</Item> block out of the model."""
    start = rbxmx_text.index('<Item class="LocalScript"')
    # walk Item open/close tags to find the matching close
    depth = 0
    i = start
    item_open = re.compile(r"<Item\b")
    pos = start
    while True:
        nxt_open = rbxmx_text.find("<Item", pos + 1)
        nxt_close = rbxmx_text.find("</Item>", pos + 1)
        if nxt_close == -1:
            raise ValueError("unterminated Item in model")
        if nxt_open != -1 and nxt_open < nxt_close:
            depth += 1
            pos = nxt_open
        else:
            if depth == 0:
                end = nxt_close + len("</Item>")
                return rbxmx_text[start:end]
            depth -= 1
            pos = nxt_close


def normalize_source(item: str) -> str:
    # place files use ProtectedString for script Source; convert for consistency
    item = item.replace('<string name="Source">', '<ProtectedString name="Source">')
    item = re.sub(
        r'(<ProtectedString name="Source"><!\[CDATA\[.*?\]\]>)</string>',
        r"\1</ProtectedString>",
        item,
        flags=re.DOTALL,
    )
    return item


def main() -> None:
    place_path, model_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    with open(place_path, "r", encoding="utf-8") as f:
        place = f.read()
    with open(model_path, "r", encoding="utf-8") as f:
        model = f.read()

    item = normalize_source(extract_localscript_item(model))
    item = "\t\t\t" + item.strip() + "\n"

    # find StarterPlayerScripts and insert as its first child (after </Properties>)
    sps = place.index('<Item class="StarterPlayerScripts"')
    props_end = place.index("</Properties>", sps) + len("</Properties>\n")

    merged = place[:props_end] + item + place[props_end:]

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(merged)
    print(f"merged cheat into StarterPlayerScripts -> {out_path}")


if __name__ == "__main__":
    main()
