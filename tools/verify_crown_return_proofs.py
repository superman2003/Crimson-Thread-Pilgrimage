"""Verify earned J -> resonance -> paid R workshop -> independent shrine restore."""
import gzip
import hashlib
import json
import re
from pathlib import Path

from verify_second_order_crown import verify as verify_preceding_chain, verify_native_restore

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / "artifacts/t04_crown_resonance_return_v19"
FIELDS = ("region", "checkpoint", "wallet", "inventory", "build", "flags", "hp", "max_hp", "energy", "max_energy")
GATE_FLAG = "action_gate_upgrade_crown_resonance_3_action_gate"
SCRIPT = "godot/scripts/world_crown_return_playback.gd"
RUNNER = "tools/run_crown_return.py"


def verify():
    verify_preceding_chain()
    index = json.loads((ROOT / "evidence_index.json").read_text(encoding="utf-8"))
    assert len(index) == 178, "complete published return archive set is required"
    files = {}
    for row in index:
        assert row["path"] not in files
        packed = (ROOT / row["archive"]).read_bytes()
        raw = gzip.decompress(packed)
        assert packed[4:8] == b"\0\0\0\0"
        assert hashlib.sha256(packed).hexdigest() == row["gzip_sha256"]
        assert hashlib.sha256(raw).hexdigest() == row["raw_sha256"] and len(raw) == row["raw_bytes"]
        if row["path"].endswith(".png") and (ROOT / row["path"]).exists():
            assert (ROOT / row["path"]).read_bytes() == raw
        files[row["path"]] = raw

    def read(name):
        return json.loads(files[name])

    for name in ("result.json", "checkpoint_proof.json", "earned_checkpoint.json"):
        original = REPO / "artifacts/t04_second_order_crown_v18/archive/native_crown_upper01" / (name + ".gz")
        assert files["source_J/" + name] == gzip.decompress(original.read_bytes())
    previous = read("source_J/checkpoint_proof.json")
    prior_bytes = files["source_J/earned_checkpoint.json"]
    assert previous["save_sha256"] == "96e2487f0b3078403a4b62184a665d43a11cb198bff3f33ae866ebf696e96c32"
    meta = read("source_commit.json")
    folders = meta["accepted_chain"]
    assert len(folders) == 2 and len(set(folders)) == 2
    pids, proofs, frozen = [previous["pid"]], [], None
    metrics = {"crown_return_resonance": (39, 2651, 1, 1, 0), "crown_resonance_workshop": (18, 1391, 0, 0, 0)}
    for folder, stage in zip(folders, ("crown_return_resonance", "crown_resonance_workshop")):
        result, proof = read(folder + "/result.json"), read(folder + "/checkpoint_proof.json")
        raw = files[folder + "/earned_checkpoint.json"]
        assert result["passed"] and result["exit"] == 0 and not result["timed_out"] and not result["launch_error"]
        assert not result["errors"] and not result["warnings"] and result["stage"] == stage
        assert result["head"] == meta["implementation_commit"]
        before = read(folder + "/source_before.json")
        assert before == read(folder + "/source_after.json") and result["source_unchanged"]
        assert len(before) == result["source_files"] >= 10000
        if frozen is None:
            frozen = before
        assert before == frozen
        for path, snapshot in ((SCRIPT, "playback.gd.txt"), (RUNNER, "runner.py.txt")):
            archived = files[folder + "/" + snapshot]
            assert hashlib.sha256(archived).hexdigest() == before[path]
            assert (REPO / path).read_bytes().replace(b"\r\n", b"\n") == archived.replace(b"\r\n", b"\n")
        assert files[folder + "/source_checkpoint.json"] == prior_bytes
        assert previous["save_sha256"] == proof["source_save_sha256"]
        assert previous["pid"] == proof["source_pid"] and proof["pid"] not in pids
        assert hashlib.sha256(raw).hexdigest() == result["checkpoint_sha256"] == proof["save_sha256"]
        assert len(raw) == proof["save_bytes"] and proof["stage"] == stage
        initial = read(folder + "/initial.json")
        for key in FIELDS:
            assert initial[key] == previous[key], (folder, key)
        assert initial["pid"] == proof["pid"] and proof["damage_enabled"] and proof["deaths"] == 0
        steps, frames, damage, heals, deaths = metrics[stage]
        assert (proof["damage_events"], proof["heals"], proof["deaths"]) == (damage, heals, deaths)
        assert result["completion"] == f"SECOND_ORDER_STAGE stage={stage} steps={steps} physics_frames={frames} damage_events={damage} heals={heals} deaths={deaths} failures=0"
        assert proof["build"] == previous["build"] and proof["checkpoint"] == "save_hidden_upper_respite"
        assert (proof["hp"], proof["max_hp"], proof["energy"], proof["max_energy"]) == (6, 6, 100, 100)
        save = json.loads(raw)
        for saved, exported in (("currency", "wallet"), ("inventory_counts", "inventory"), ("build_state", "build"), ("story_flags", "flags"), ("current_region", "region"), ("hp", "hp"), ("energy", "energy")):
            assert save[saved] == proof[exported], (folder, saved)
        command = read(folder + "/command.json")
        assert command["timeout"] == 180 and "--headless" not in command["command"]
        for flag, value in (("--fixed-fps", "60"), ("--audio-driver", "Dummy"), ("--display-driver", "windows")):
            assert command["command"][command["command"].index(flag) + 1] == value
        log = files[folder + "/runtime.log"].decode("utf-8")
        assert "Godot Engine v4.6.1.stable.official.14d19694e" in log and "NVIDIA" in log
        assert result["completion"] in log and not re.search(r"^(?:SCRIPT ERROR:|ERROR:|WARNING:)", log, re.M)
        assert json.loads(re.search(r"^SECOND_ORDER_EARNED (.+)$", log, re.M).group(1)) == proof
        assert json.loads(re.search(r"^SECOND_ORDER_INITIAL (.+)$", log, re.M).group(1)) == initial
        proofs.append(proof)
        pids.append(proof["pid"])
        previous, prior_bytes = proof, raw

    j = read("source_J/checkpoint_proof.json")
    k, l = proofs
    expected = dict(j["inventory"], crown_echo_shard=27, crown_resonance=1)
    assert j["wallet"] == 193 and k["wallet"] == j["wallet"] + 6 * 8 == 241
    assert k["inventory"] == expected and k["observed_enemy_defeats"] == ["E07", "E13", "E08", "E12", "E09", "E10"]
    assert k["flags"]["elite_first_demo_ch06_silent_crown_core_E08"] and not k["flags"].get(GATE_FLAG, False)
    expected["upgrade_crown_resonance_3_record"] = 1
    assert l["inventory"] == expected and l["wallet"] == k["wallet"] + 75 == 316
    assert l["flags"][GATE_FLAG] and l["observed_enemy_defeats"] == []
    assert l["damage_events"] == l["heals"] == 0
    action = read(folders[1] + "/resonance_action.json")
    assert action["pid"] == l["pid"] and action["observed_actions"] == 1
    assert (action["energy_before"], action["energy_after"], action["gate_before"], action["gate_after"]) == (100, 80, False, True)
    log = files[folders[1] + "/runtime.log"].decode("utf-8")
    blocked = json.loads(re.search(r"^CROWN_RETURN_GATE_BLOCKED (.+)$", log, re.M).group(1))
    blocked_x = float(blocked["position"].split(",")[0].lstrip("("))
    assert blocked["wall"] and blocked["energy"] == 100 and 6090 < blocked_x < 6130
    assert len(re.findall(r'^SECOND_ORDER_ABILITY_EVENT .*"id":"crown_resonance"', log, re.M)) == 1
    for marker in ("CROWN_RETURN_PORTAL ", "CROWN_RETURN_CAGE_CALL_BEFORE ", "CROWN_RETURN_CAGE_CALL_AFTER "):
        assert log.count(marker) == (2 if marker == "CROWN_RETURN_PORTAL " else 1)
    chain_pids = list(pids)
    restore = meta["accepted_restore"]
    for folder, source in (("native_J_restore01", "source_J"), (restore, folders[-1])):
        verify_native_restore(files, folder, source, meta["implementation_commit"], frozen, pids, SCRIPT, RUNNER)
    assert "PASS independent production restore physically omits the paid R gate" in files[restore + "/runtime.log"].decode("utf-8")
    negative = "negative_attack_instead_of_R01/"
    result = read(negative + "result.json")
    assert result["exit"] == 1 and not result["passed"] and result["source_unchanged"] and not result["warnings"]
    assert not result["timed_out"] and not result["launch_error"]
    assert read(negative + "source_before.json") == read(negative + "source_after.json")
    assert files[negative + "source_checkpoint.json"] == files[folders[0] + "/earned_checkpoint.json"]
    assert len(result["errors"]) == 1 and "one actual R action pays twenty thread" in result["errors"][0]
    action = read(negative + "resonance_action.json")
    assert (action["energy_before"], action["energy_after"], action["observed_actions"], action["gate_after"]) == (100, 100, 0, False)
    altered = files[negative + "playback.gd.txt"].replace(b"\r\n", b"\n")
    normal = files[folders[1] + "/playback.gd.txt"].replace(b"\r\n", b"\n")
    assert altered == normal.replace(b'Input.action_press("crown_resonance");await process_frame;await _tick(2)', b'Input.action_press("attack");await process_frame;await _tick(2)')
    attempts = {f"calibration_return{x:02}" for x in range(1, 5)} | {f"calibration_workshop{x:02}" for x in range(1, 3)}
    assert {name.split("/")[0] for name in files if name.startswith("calibration_")} == attempts
    passed = {"calibration_return04", "calibration_workshop02"}
    for folder in attempts:
        result = read(folder + "/result.json")
        assert result["passed"] == (folder in passed)
        assert result["exit"] == (0 if folder in passed else 1)
        assert read(folder + "/terminal.json")["deaths"] == 0
        for required in ("runtime.log", "command.json", "lineage.json", "source_checkpoint.json", "source_before.json", "source_after.json", "playback.gd.txt", "runner.py.txt"):
            assert folder + "/" + required in files
    rejected = read("rejected_sources.json")
    assert len(rejected) == 3 and all(x["rejected_before_engine_launch"] for x in rejected)
    npm = read("npm_results.json")
    assert len(npm) == 2 and {x["name"] for x in npm} == {"npm_test", "campaign"} and all(x["exit"] == 0 for x in npm)
    print(f"PASS {len(index)} return archives; earned J-K-L PIDs {chain_pids}; six normal return rewards; actual R 100->80; workshop +75; both clean restores; ordinary-attack negative")


if __name__ == "__main__":
    verify()
