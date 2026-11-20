"""Collect authored strings for the English catalogue and its coverage check."""
import ast
import json
import re
from pathlib import Path

GODOT = Path(__file__).resolve().parents[1] / "godot"
HAN = re.compile(r"[\u3400-\u9fff]")
TOKEN = re.compile(r"""\#[^\n]*|"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'""")
TEST_SCRIPT = re.compile(r"(^capture_|^preview_|_validation$|_checks$|_playback$|_fixture$|_preview$|_capture$|_probe$)")
INTERNAL = {"asset_policy", "open_assets", "design_note", "design_reference", "asset_hint",
            "asset_source", "license"}


def script_strings(path):
    for match in TOKEN.finditer(path.read_text(encoding="utf-8-sig")):
        literal = match.group()
        if literal.startswith("#") or not HAN.search(literal):
            continue
        yield ast.literal_eval(literal) if "\\" in literal else literal[1:-1]


def data_strings(value):
    if isinstance(value, str):
        if HAN.search(value) and not value.startswith(("res://", "docs/", "godot/")):
            yield value
    elif isinstance(value, dict):
        for key, child in value.items():
            if not key.startswith("_") and key not in INTERNAL:
                yield from data_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from data_strings(child)


def inventory():
    for folder in ("scripts", "journey", "scenes"):
        for path in sorted((GODOT / folder).rglob("*")):
            if path.suffix not in {".gd", ".tscn"} or "tests" in path.parts or TEST_SCRIPT.search(path.stem):
                continue
            yield path, set(script_strings(path))
    for path in sorted((GODOT / "data").rglob("*.json")):
        if path.name.startswith(("ui_translations", "ui_en_")) or "credits" in path.parts:
            continue
        yield path, set(data_strings(json.loads(path.read_text(encoding="utf-8-sig"))))
