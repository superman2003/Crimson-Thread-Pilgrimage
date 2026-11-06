"""Verify the alternate-order G -> H -> I -> J native crown continuation."""
import gzip
import hashlib
import json
import re
from pathlib import Path

from verify_second_order_continuation import verify as verify_preceding_chain

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / "artifacts/t04_second_order_crown_v18"
REGION = "demo_ch06_silent_crown_core"
FIELDS = ("region", "checkpoint", "wallet", "inventory", "build", "flags", "hp", "max_hp", "energy", "max_energy")


def verify():
    verify_preceding_chain()
    index = json.loads((ROOT / "evidence_index.json").read_text(encoding="utf-8"))
    files = {}
    for item in index:
        assert item["path"] not in files, item["path"]
        packed = (ROOT / item["archive"]).read_bytes()
        raw = gzip.decompress(packed)
        assert packed[4:8] == b"\0\0\0\0"
        assert hashlib.sha256(packed).hexdigest() == item["gzip_sha256"]
        assert hashlib.sha256(raw).hexdigest() == item["raw_sha256"]
        assert len(raw) == item["raw_bytes"]
        files[item["path"]] = raw

    def read(path):
        return json.loads(files[path])

    for name in ("result.json", "checkpoint_proof.json", "earned_checkpoint.json"):
        original = REPO / "artifacts/t04_second_order_greenhouse/archive/native_root_crown01" / (name + ".gz")
        assert files["source_G/" + name] == gzip.decompress(original.read_bytes())
    previous = read("source_G/checkpoint_proof.json")
    prior_bytes = files["source_G/earned_checkpoint.json"]
    assert previous["save_sha256"] == "abf718c2e0ed5b7a995715872a381337e52d655178e02e8afa541e1e822db417"
    meta = read("source_commit.json")
    pids = [previous["pid"]]
    proofs = []
    frozen = None
    for folder, stage in (("native_crown_map01", "crown_map"), ("native_crown_west01", "crown_west"), ("native_crown_upper01", "crown_upper")):
        result, proof = read(folder + "/result.json"), read(folder + "/checkpoint_proof.json")
        raw = files[folder + "/earned_checkpoint.json"]
        assert result["passed"] and result["exit"] == 0 and not result["timed_out"] and not result["launch_error"]
        assert result["head"] == meta["implementation_commit"] and result["stage"] == stage
        assert not result["errors"] and not result["warnings"]
        before = read(folder + "/source_before.json")
        assert before == read(folder + "/source_after.json")
        assert result["source_unchanged"] and len(before) == result["source_files"] >= 10000
        if frozen is None:
            frozen = before
        assert before == frozen, "all accepted native stages use the same frozen inputs"
        for name, snapshot in (("godot/scripts/world_second_order_playback.gd", "playback.gd.txt"), ("tools/run_second_order.py", "runner.py.txt")):
            archived = files[folder + "/" + snapshot]
            assert hashlib.sha256(archived).hexdigest() == before[name]
            assert (REPO / name).read_bytes().replace(b"\r\n", b"\n") == archived.replace(b"\r\n", b"\n")
        assert files[folder + "/source_checkpoint.json"] == prior_bytes
        lineage = read(folder + "/lineage.json")
        assert lineage["source_pid"] == previous["pid"] == proof["source_pid"]
        assert lineage["source_sha256"] == previous["save_sha256"] == proof["source_save_sha256"]
        assert proof["pid"] not in pids and proof["stage"] == stage
        assert hashlib.sha256(raw).hexdigest() == proof["save_sha256"] == result["checkpoint_sha256"]
        assert len(raw) == proof["save_bytes"]
        initial = read(folder + "/initial.json")
        for key in FIELDS:
            assert initial[key] == previous[key], (folder, key)
        assert initial["pid"] == proof["pid"] and proof["damage_enabled"] and proof["deaths"] == 0
        assert proof["build"] == previous["build"]
        assert (proof["hp"], proof["max_hp"], proof["energy"], proof["max_energy"]) == (6, 6, 100, 100)
        for ability in ("thread_dash", "bell_guard", "grapple_hook", "crown_resonance", "compass"):
            assert not proof["inventory"].get(ability, 0), ability
        save = json.loads(raw)
        for saved, exported in (("currency", "wallet"), ("inventory_counts", "inventory"), ("build_state", "build"), ("story_flags", "flags"), ("current_region", "region"), ("hp", "hp"), ("energy", "energy")):
            assert save[saved] == proof[exported], (folder, saved)
        command = read(folder + "/command.json")
        assert command["timeout"] == 180 and "--headless" not in command["command"]
        for flag, value in (("--fixed-fps", "60"), ("--audio-driver", "Dummy"), ("--display-driver", "windows")):
            assert command["command"][command["command"].index(flag) + 1] == value
        log = files[folder + "/runtime.log"].decode("utf-8")
        assert "Godot Engine v4.6.1.stable.official.14d19694e" in log and "NVIDIA" in log
        assert result["completion"] in log
        assert json.loads(re.search(r"^SECOND_ORDER_EARNED (.+)$", log, re.M).group(1)) == proof
        assert json.loads(re.search(r"^SECOND_ORDER_INITIAL (.+)$", log, re.M).group(1)) == initial
        assert not re.search(r"^(?:SCRIPT ERROR:|ERROR:|WARNING:)", log, re.M)
        proofs.append(proof)
        pids.append(proof["pid"])
        previous, prior_bytes = proof, raw

    g, h, i, j = read("source_G/checkpoint_proof.json"), *proofs
    assert g["wallet"] == 154 and h["wallet"] == 99 and h["inventory"] == g["inventory"]
    assert h["observed_enemy_defeats"] == []
    quote = files["native_crown_map01/runtime.log"].decode("utf-8")
    assert '"price":55' in quote and "当前154枚 → 购买后99枚" in quote
    chart = h["flags"]["cartography_v1"][REGION]
    assert chart["owned"] and not chart["pending"] and len(chart["charted"]) == 6
    expected = dict(h["inventory"], crown_echo_shard=19)
    assert i["wallet"] == h["wallet"] + 6 * 8 + 30 == 177 and i["inventory"] == expected
    assert i["observed_enemy_defeats"] == ["E07", "E13", "E08", "E12", "E09", "E10"]
    assert i["checkpoint"] == "save_hidden_upper_respite"
    assert i["flags"]["hidden_found_ch06_echo_moss"]
    expected.update(crown_echo_shard=21, testimony_06=1)
    assert j["wallet"] == i["wallet"] + 16 == 193 and j["inventory"] == expected
    assert j["observed_enemy_defeats"] == ["E07", "E14"] and j["checkpoint"] == "save_late_runback"
    log = files["native_crown_upper01/runtime.log"].decode("utf-8")
    assert log.count("SECOND_ORDER_CROWN_CAGE_BEFORE ") == log.count("SECOND_ORDER_CROWN_CAGE_AFTER ") == 2
    assert '"up":true' in log and '"up":false' in log
    restored = read("native_crown_restore01/initial.json")
    restore = read("native_crown_restore01/result.json")
    assert restore["passed"] and restore["head"] == meta["implementation_commit"]
    assert read("native_crown_restore01/source_before.json") == read("native_crown_restore01/source_after.json") == frozen
    assert restored["pid"] not in pids and files["native_crown_restore01/source_checkpoint.json"] == prior_bytes
    assert restored["deaths"] == restored["damage_events"] == restored["heals"] == 0
    for key in FIELDS:
        assert restored[key] == j[key], key
    assert not read("calibration_upper01/result.json")["passed"]
    assert read("calibration_upper01/terminal.json")["deaths"] == 1, "failed calibration death stays recorded"
    negatives = read("rejected_sources.json")
    assert len(negatives) == 3 and all(x["rejected_before_engine_launch"] for x in negatives)
    print(f"PASS {len(index)} crown archives; native G-H-I-J chain PIDs {pids}; paid 55; 6 west + 2 returning guards; independent front-shrine restore")


if __name__ == "__main__":
    verify()
