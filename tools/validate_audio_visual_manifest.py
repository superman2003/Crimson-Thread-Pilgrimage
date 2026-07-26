from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "godot" / "data" / "audio_visual_manifest.json"
CAMPAIGN = ROOT / "godot" / "data" / "campaign_chapters.json"

REQUIRED_RUNTIME_KEYS = {
    "player_attack",
    "player_hook",
    "player_skill",
    "player_heal",
    "enemy_windup",
    "enemy_attack",
    "boss_attack",
    "pickup",
}
FORBIDDEN_TERMS = {
    "\u81ea\u5236",
    "\u751f\u6210",
    "\u4ed8\u8d39\u5fc5\u9700",
    "".join(("paid", " required")),
    "".join(("premium", " required")),
    "".join(("patreon", " collection")),
}
FUTURE_POLICY_MARKERS = ("CC0", "Public Domain", "Apache-2.0", "free commercial-use")


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_json(path: Path) -> dict[str, Any]:
    assert_true(path.exists(), f"missing json file: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    assert_true(isinstance(data, dict), f"json root must be object: {path.name}")
    return data


def res_to_path(path: str) -> Path:
    assert_true(path.startswith("res://"), f"audio path must use res://: {path}")
    return ROOT / "godot" / path.removeprefix("res://")


def walk_audio_entries(value: Any, pointer: str = "$") -> Iterable[tuple[str, dict[str, Any]]]:
    """遍历清单中所有带 status 的音频条目：wired/asset_ready/local_audio 均需校验落地 path，
    future_free_candidate 仍允许无 path。"""
    if isinstance(value, dict):
        status = value.get("status")
        if status in {"wired", "asset_ready", "local_audio", "future_free_candidate"}:
            yield pointer, value
        for key, child in value.items():
            yield from walk_audio_entries(child, f"{pointer}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from walk_audio_entries(child, f"{pointer}[{index}]")


def walk_implemented_in(value: Any, pointer: str = "$") -> Iterable[tuple[str, str]]:
    if isinstance(value, dict):
        if "implemented_in" in value:
            yield pointer, str(value["implemented_in"])
        for key, child in value.items():
            yield from walk_implemented_in(child, f"{pointer}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from walk_implemented_in(child, f"{pointer}[{index}]")


def validate_implemented_in(pointer: str, implemented_in: str) -> None:
    """implemented_in 约定形如 "res://scripts/xxx.gd::func (note)"，脚本文件必须存在。"""
    assert_true(
        implemented_in.startswith("res://"),
        f"{pointer} implemented_in must start with res://: {implemented_in}",
    )
    script_ref = implemented_in.split("::", 1)[0]
    assert_true(
        res_to_path(script_ref).exists(),
        f"{pointer} implemented_in script missing: {script_ref}",
    )


def validate_audio_entry(pointer: str, entry: dict[str, Any]) -> str:
    key = str(entry.get("key", ""))
    assert_true(key, f"{pointer} audio entry missing key")
    status = entry.get("status")
    if status == "local_audio":
        path = str(entry.get("path", ""))
        assert_true(path.endswith(".ogg"), f"{pointer} local audio must be ogg: {path}")
        assert_true(res_to_path(path).exists(), f"{pointer} local audio missing: {path}")
        assert_true(bool(entry.get("recorded_source")), f"{pointer} local audio missing recorded_source")
        assert_true(bool(entry.get("license")), f"{pointer} local audio missing license")
        return "local"
    if status in {"wired", "asset_ready"}:
        path = str(entry.get("path", ""))
        assert_true(
            path.endswith(".ogg") or path.endswith(".wav"),
            f"{pointer} {status} audio must be ogg/wav: {path}",
        )
        assert_true(res_to_path(path).exists(), f"{pointer} {status} audio missing: {path}")
        return "wired" if status == "wired" else "asset_ready"
    if status == "future_free_candidate":
        assert_true("path" not in entry, f"{pointer} future candidate must not point to a missing local file")
        policy = str(entry.get("free_policy", ""))
        assert_true(
            any(marker in policy for marker in FUTURE_POLICY_MARKERS),
            f"{pointer} future candidate missing free/open policy",
        )
        return "future"
    raise AssertionError(f"{pointer} unsupported audio status: {status}")


def validate_runtime_events(manifest: dict[str, Any]) -> None:
    runtime_events = manifest.get("runtime_events", {})
    assert_true(isinstance(runtime_events, dict), "runtime_events must be object")
    missing = REQUIRED_RUNTIME_KEYS - set(runtime_events)
    assert_true(not missing, "runtime_events missing required keys: " + ", ".join(sorted(missing)))

    for key in sorted(REQUIRED_RUNTIME_KEYS):
        event = runtime_events[key]
        assert_true(event.get("implemented_in"), f"{key} missing implemented_in")
        assert_true(event.get("vfx"), f"{key} missing vfx entries")
        assert_true(event.get("audio"), f"{key} missing audio entries")
        for vfx in event.get("vfx", []):
            assert_true(vfx.get("source_policy") == "godot_programmatic_vfx", f"{key} vfx must be Godot programmatic")


def validate_chapter_beats(manifest: dict[str, Any], campaign: dict[str, Any]) -> None:
    manifest_chapters = manifest.get("chapter_audio_visual", [])
    campaign_chapters = campaign.get("chapters", [])
    assert_true(len(manifest_chapters) == 6, "manifest must define CH01-CH06 audio visual chapters")
    assert_true(len(campaign_chapters) == 6, "campaign must define CH01-CH06")

    by_id = {chapter.get("chapter_id"): chapter for chapter in manifest_chapters}
    for campaign_chapter in campaign_chapters:
        chapter_id = campaign_chapter.get("id")
        manifest_chapter = by_id.get(chapter_id)
        assert_true(manifest_chapter is not None, f"manifest missing chapter: {chapter_id}")
        assert_true(
            manifest_chapter.get("chapter_index") == campaign_chapter.get("index"),
            f"{chapter_id} chapter index mismatch",
        )
        assert_true(manifest_chapter.get("music"), f"{chapter_id} missing music requirements")

        campaign_beats = list(campaign_chapter.get("vfx_audio", []))
        manifest_beats = list(manifest_chapter.get("beats", []))
        assert_true(len(manifest_beats) == len(campaign_beats), f"{chapter_id} beat count mismatch")
        manifest_beat_text = [beat.get("campaign_beat") for beat in manifest_beats]
        assert_true(manifest_beat_text == campaign_beats, f"{chapter_id} beat text/order must match campaign")

        for beat in manifest_beats:
            assert_true(beat.get("vfx"), f"{chapter_id}/{beat.get('campaign_beat')} missing vfx")
            assert_true(beat.get("audio"), f"{chapter_id}/{beat.get('campaign_beat')} missing audio")


def main() -> None:
    manifest_text = MANIFEST.read_text(encoding="utf-8") if MANIFEST.exists() else ""
    lowered = manifest_text.lower()
    for term in FORBIDDEN_TERMS:
        assert_true(term.lower() not in lowered, f"manifest contains forbidden term: {term}")

    manifest = load_json(MANIFEST)
    campaign = load_json(CAMPAIGN)
    validate_runtime_events(manifest)
    validate_chapter_beats(manifest, campaign)

    counts = {"local": 0, "wired": 0, "asset_ready": 0, "future": 0}
    for pointer, entry in walk_audio_entries(manifest):
        counts[validate_audio_entry(pointer, entry)] += 1

    implemented_count = 0
    for pointer, implemented_in in walk_implemented_in(manifest):
        validate_implemented_in(pointer, implemented_in)
        implemented_count += 1

    assert_true(counts["local"] >= 8, "manifest should include existing local runtime audio references")
    assert_true(counts["wired"] >= 100, "manifest should keep the wired sfx/music catalog referenced")
    assert_true(implemented_count >= 100, "manifest should document implemented_in wiring for wired entries")
    print(
        "AUDIO_VISUAL_MANIFEST_VALIDATION_PASS "
        f"runtime_keys={len(REQUIRED_RUNTIME_KEYS)} chapters=6 "
        f"wired={counts['wired']} asset_ready={counts['asset_ready']} local_audio={counts['local']} "
        f"future_free_candidate={counts['future']} implemented_in={implemented_count}"
    )


if __name__ == "__main__":
    main()
