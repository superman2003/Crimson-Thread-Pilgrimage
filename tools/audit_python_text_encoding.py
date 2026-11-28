#!/usr/bin/env python3
"""Require explicit UTF-8 for text file access in repository Python tools."""
from __future__ import annotations

import ast
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
SKIP_MODULES = {"Image", "wave", "webbrowser", "zipfile", "tarfile"}


def _encoding_supplied(call: ast.Call, encoding_position: int) -> bool:
    return any(keyword.arg == "encoding" for keyword in call.keywords) or len(call.args) > encoding_position


def _text_call(call: ast.Call, path: Path) -> bool:
    function = call.func
    if isinstance(function, ast.Name):
        if function.id != "open":
            return False
        mode_position = 1
        encoding_position = 3
    elif isinstance(function, ast.Attribute):
        receiver = ast.unparse(function.value)
        if function.attr == "read_text":
            return not _encoding_supplied(call, 0)
        if function.attr == "write_text":
            return not _encoding_supplied(call, 1)
        if function.attr != "open":
            return False
        receiver_root = receiver.split(".", 1)[0]
        if receiver_root in SKIP_MODULES:
            return False
        if path.name in {"build_release.py", "download_godot_release.py"} and receiver == "source":
            return False
        if receiver == "archive":
            return False
        mode_position = 0
        encoding_position = 2
        if receiver in {"io"}:
            mode_position = 1
            encoding_position = 3
        elif receiver == "codecs":
            mode_position = 1
            encoding_position = 2
    else:
        return False

    mode = None
    if len(call.args) > mode_position and isinstance(call.args[mode_position], ast.Constant):
        value = call.args[mode_position].value
        mode = value if isinstance(value, str) else None
    if mode is None:
        for keyword in call.keywords:
            if keyword.arg == "mode" and isinstance(keyword.value, ast.Constant):
                value = keyword.value.value
                mode = value if isinstance(value, str) else None
                break
    if mode is not None and "b" in mode:
        return False
    return not _encoding_supplied(call, encoding_position)


def missing_text_encoding(source: str, path: Path) -> list[tuple[int, str]]:
    try:
        tree = ast.parse(source, filename=str(path))
    except SyntaxError:
        return []
    return [(node.lineno, ast.unparse(node.func)) for node in ast.walk(tree)
            if isinstance(node, ast.Call) and _text_call(node, path)]


def audit(root: Path = TOOLS) -> list[str]:
    errors = []
    for path in sorted(root.rglob("*.py")):
        if "__pycache__" in path.parts:
            continue
        raw = path.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            errors.append(f"{path.relative_to(ROOT)}:1: remove UTF-8 BOM from Python source")
            text = raw.decode("utf-8-sig")
        else:
            text = raw.decode("utf-8")
        for line, function in missing_text_encoding(text, path):
            errors.append(f"{path.relative_to(ROOT)}:{line}: {function} needs encoding=\"utf-8\"")
    return errors


def self_test() -> None:
    path = Path("tools/self_test.py")
    assert missing_text_encoding('Path("x").read_text()', path)
    assert missing_text_encoding('Path("x").write_text("text")', path)
    assert missing_text_encoding('open("x")', path)
    assert not missing_text_encoding('Path("x").read_text(encoding="utf-8")', path)
    assert not missing_text_encoding('Path("x").read_bytes()', path)
    assert not missing_text_encoding('open("x", "rb")', path)
    assert not missing_text_encoding('Image.open("x.png")', path)
    assert not missing_text_encoding('archive.open("x.bin")', path)
    assert not missing_text_encoding('with zipfile.ZipFile("x.zip") as source:\n    source.open("x.bin")', Path("tools/download_godot_release.py"))


def main() -> int:
    if "--self-test" in sys.argv:
        self_test()
        print("PYTHON_TEXT_ENCODING self-test OK")
        return 0
    errors = audit()
    for error in errors:
        print("PYTHON_TEXT_ENCODING", error)
    print(f"PYTHON_TEXT_ENCODING files={len(list(TOOLS.rglob('*.py')))} errors={len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
