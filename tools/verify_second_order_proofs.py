"""Verify the archived fresh A -> B -> C bytes, provenance, and failed attempts."""
import gzip
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "artifacts/t04_second_order"


def verify():
    index = json.loads((ROOT / "evidence_index.json").read_text(encoding="utf-8"))
    archived = {}
    for entry in index:
        packed = (ROOT / entry["archive"]).read_bytes()
        raw = gzip.decompress(packed)
        assert packed[4:8] == b"\0\0\0\0", entry["path"]
        assert hashlib.sha256(packed).hexdigest() == entry["gzip_sha256"]
        assert hashlib.sha256(raw).hexdigest() == entry["raw_sha256"]
        assert len(raw) == entry["raw_bytes"]
        archived[entry["path"]] = raw

    def read(name):
        return json.loads(archived[name])

    previous = None
    pids = []
    for stage in ["native_first_lamp01", "native_canal01", "native_archive_branch01"]:
        result = read(stage + "/result.json")
        proof = read(stage + "/checkpoint_proof.json")
        raw = archived[stage + "/earned_checkpoint.json"]
        assert result["passed"] and result["exit"] == 0
        assert not result["errors"] and not result["warnings"]
        assert read(stage + "/source_before.json") == read(stage + "/source_after.json")
        assert hashlib.sha256(raw).hexdigest() == result["checkpoint_sha256"] == proof["save_sha256"]
        assert proof["damage_enabled"] and proof["deaths"] == 0
        assert proof["build"]["crest"] == "crimson"
        assert proof["build"]["passives"] == []
        assert not proof["flags"].get("cartography_v1", {}).get("demo_ch04_broken_string_greenhouse")
        if previous:
            assert archived[stage + "/source_checkpoint.json"] == previous[1]
            assert proof["source_pid"] == previous[0]["pid"]
            assert proof["source_save_sha256"] == previous[0]["save_sha256"]
        else:
            initial = read(stage + "/initial.json")
            assert initial["wallet"] == 0 and initial["hp"] == initial["max_hp"] == 5
            assert initial["inventory"] == {"thread_burst": 1, "menders_right": 1, "moss_lens": 1}
        pids.append(proof["pid"])
        previous = proof, raw
    assert len(set(pids)) == 3
    assert previous[0]["checkpoint"] == "save_ch05_lower_loop"
    assert previous[0]["inventory"]["lantern_phase"] == 1
    assert previous[0]["inventory"]["double_thread_jump"] == 1
    assert previous[0]["wallet"] == 158
    restore = read("cpu_camp_restore01/initial.json")
    assert read("cpu_camp_restore01/result.json")["passed"]
    assert restore["pid"] not in pids
    for key in ["inventory", "wallet", "build", "flags", "hp", "energy", "max_hp", "max_energy", "checkpoint"]:
        assert restore[key] == previous[0][key], key
    deaths = sum(read(name)["actual_deaths"] for name in archived if name.endswith("/failure_audit.json"))
    assert deaths == 5, deaths
    assert read("npm_results.json") == {"npm_campaign_exit": 0, "npm_test_exit": 0}
    print(f"PASS {len(index)} exact archives; native PIDs {pids}; independent camp restore; CPU deaths {deaths}")


if __name__ == "__main__":
    verify()
