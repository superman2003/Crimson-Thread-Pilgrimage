"""Check actual D-G archives against the original fresh A-C checkpoint chain."""
import gzip
import hashlib
import json
import re
from pathlib import Path

from verify_second_order_proofs import verify as verify_first_stages

ROOT = Path(__file__).resolve().parents[1] / "artifacts/t04_second_order_greenhouse"


def verify():
    verify_first_stages()
    records = json.loads((ROOT / "evidence_index.json").read_text(encoding="utf-8"))
    files = {}
    for item in records:
        packed = (ROOT / item["archive"]).read_bytes()
        raw = gzip.decompress(packed)
        assert packed[4:8] == b"\0\0\0\0"
        assert hashlib.sha256(packed).hexdigest() == item["gzip_sha256"]
        assert hashlib.sha256(raw).hexdigest() == item["raw_sha256"]
        assert len(raw) == item["raw_bytes"]
        files[item["path"]] = raw
        if item["path"].endswith(".png"):
            assert (ROOT / item["path"]).read_bytes() == raw

    def read(path):
        return json.loads(files[path])

    previous = json.loads(gzip.decompress((ROOT.parent / "t04_second_order/archive/native_archive_branch01/checkpoint_proof.json.gz").read_bytes()))
    prior_bytes = gzip.decompress((ROOT.parent / "t04_second_order/archive/native_archive_branch01/earned_checkpoint.json.gz").read_bytes())
    proofs = []
    pids = [previous["pid"]]
    stages = ["native_camp_prepare01", "native_greenhouse_entry01", "native_greenhouse_heart01", "native_root_crown01"]
    for stage in stages:
        result, proof = read(stage + "/result.json"), read(stage + "/checkpoint_proof.json")
        raw = files[stage + "/earned_checkpoint.json"]
        assert result["passed"] and result["exit"] == 0 and not result["timed_out"]
        assert not result["errors"] and not result["warnings"]
        before, after = read(stage + "/source_before.json"), read(stage + "/source_after.json")
        assert before == after and len(before) == result["source_files"] >= 9000
        assert proof["pid"] not in pids
        assert proof["source_pid"] == previous["pid"]
        assert files[stage + "/source_checkpoint.json"] == prior_bytes
        assert proof["source_save_sha256"] == previous["save_sha256"]
        assert hashlib.sha256(raw).hexdigest() == proof["save_sha256"] == result["checkpoint_sha256"]
        assert proof["damage_enabled"] and proof["deaths"] == 0
        assert proof["build"]["crest"] == "crimson"
        assert proof["build"]["passives"] == ["stride"]
        assert proof["build"]["equipped_families"]["travel_accessory"] == ["stride", "", ""]
        assert proof["build"]["unlocked_crests"] == ["crimson"]
        assert not proof["inventory"].get("thread_dash", 0)
        command = read(stage + "/command.json")
        assert command["timeout"] == 180 and "--headless" not in command["command"]
        assert command["command"][command["command"].index("--fixed-fps") + 1] == "60"
        log = files[stage + "/runtime.log"].decode("utf-8")
        assert result["completion"] in log
        assert json.loads(re.search(r"^SECOND_ORDER_EARNED (.+)$", log, re.M).group(1)) == proof
        proofs.append(proof)
        pids.append(proof["pid"])
        previous, prior_bytes = proof, raw

    d, e, f, g = proofs
    original = read("native_camp_prepare01/initial.json")
    assert d["inventory"] == original["inventory"] and d["wallet"] == original["wallet"] == 158
    assert d["hp"] == original["hp"] and d["energy"] == original["energy"]
    assert d["build"]["loadouts"]["巡礼方案 1"]["passives"] == []
    assert d["build"]["loadouts"]["巡礼方案 2"]["passives"] == ["stride"]
    assert e["wallet"] == d["wallet"] - 50 - 10 + 8 == 106
    assert e["flags"]["cartography_quill"]
    chart = e["flags"]["cartography_v1"]["demo_ch05_obsidian_pilgrim_road"]
    assert chart["owned"] and len(chart["charted"]) == 12 and not chart["pending"]
    assert not d["flags"]["cartography_v1"].get("demo_ch04_broken_string_greenhouse")
    assert e["flags"]["cartography_v1"]["demo_ch04_broken_string_greenhouse"]["pending"]
    assert f["wallet"] == e["wallet"] + 16 == 122
    assert f["inventory"]["testimony_04"] == f["inventory"]["thorn_downstrike"] == 1
    assert g["wallet"] == f["wallet"] + 32 == 154
    assert g["inventory"]["pollen_wax"] == 9 and g["inventory"]["crown_echo_shard"] == 8
    assert not g["inventory"].get("crown_resonance", 0)
    assert not f["flags"]["cartography_v1"].get("demo_ch06_silent_crown_core")
    assert g["flags"]["cartography_v1"]["demo_ch06_silent_crown_core"]["pending"]
    assert g["checkpoint"] == "save_ch06_lower_loop"
    assert g["build"]["loadouts"] == d["build"]["loadouts"]
    restored = read("cpu_crown_restore01/initial.json")
    assert read("cpu_crown_restore01/result.json")["passed"] and restored["pid"] not in pids
    for key in ["inventory", "wallet", "build", "flags", "checkpoint", "hp", "max_hp", "energy", "max_energy"]:
        assert restored[key] == g[key], key
    for path, raw in files.items():
        if path.startswith("cpu_") and path.endswith("/terminal.json"):
            assert json.loads(raw)["deaths"] == 0, path
    npm = read("npm_results.json")
    assert npm["pythonutf8_npm_test_exit"] == npm["pythonutf8_npm_campaign_exit"] == 0
    assert npm["default_gbk_npm_test_exit"] == npm["default_gbk_npm_campaign_exit"] == 1
    print(f"PASS {len(records)} exact continuation archives; D-G PIDs {pids[1:]}; original C bytes; paid 50+10; independent C6 restore")


if __name__ == "__main__":
    verify()
