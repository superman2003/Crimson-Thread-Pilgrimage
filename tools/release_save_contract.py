"""Exercise delivered player saves, with no editor, source path or test script.

Fixtures live in a disposable OS user profile. Corrupt saves are expected to
remain blocked until the player explicitly chooses recovery in the UI; this
gate does not simulate that choice or claim full gameplay acceptance.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import tempfile

SAVE_NAMES = {1: 'pilgrimage_world.json', 2: 'pilgrimage_world_slot_2.json',
              3: 'pilgrimage_world_slot_3.json'}
PROBE_FLAG = 'release_slot_resume_probe'
PROGRESS_FIELDS = ('current_region', 'currency', 'inventory_counts', 'build_state',
                   'story_flags', 'death_cache')


def read_save(path: Path) -> dict:
    """Inspect the real player's write, rather than accepting a log marker."""
    if not path.is_file():
        raise ValueError(f'Player did not create slot save: {path.name}')
    data = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(data, dict) or not isinstance(data.get('current_region'), str) or not data['current_region']:
        raise ValueError(f'Incomplete slot save: {path.name}')
    if not isinstance(data.get('regions'), dict) or not data['regions']:
        raise ValueError(f'Missing slot regions: {path.name}')
    if not isinstance(data.get('story_flags'), dict):
        raise ValueError(f'Missing slot story flags: {path.name}')
    value = data.get('currency')
    if type(value) not in (int, float) or value < 0 or not float(value).is_integer():
        raise ValueError(f'Invalid slot currency: {path.name}')
    for field in ('inventory_counts', 'build_state', 'death_cache'):
        if not isinstance(data.get(field), dict):
            raise ValueError(f'Missing slot progress field {field}: {path.name}')
    return data


def locate_save(user_data: Path, slot: int) -> Path:
    matches = list(user_data.rglob(SAVE_NAMES[slot]))
    if len(matches) != 1:
        raise ValueError(f'Expected exactly one isolated slot {slot} save; found {len(matches)}')
    return matches[0]


def family_snapshot(user_data: Path) -> dict[str, bytes]:
    """Include backup, stage, recovery and quarantine files as evidence too."""
    return {p.relative_to(user_data).as_posix(): p.read_bytes()
            for p in sorted(user_data.rglob('pilgrimage_world*')) if p.is_file()}


def progress(data: dict) -> dict:
    return {key: data.get(key) for key in PROGRESS_FIELDS}


def ensure_unchanged(before: dict, after: dict, context: str) -> None:
    if before != after:
        changed = sorted(key for key in before.keys() | after.keys() if before.get(key) != after.get(key))
        raise ValueError(f'{context}: save evidence changed: {", ".join(changed)}')


def sibling_snapshot(user_data: Path, selected: Path) -> dict[str, bytes]:
    prefix = selected.relative_to(user_data).as_posix()
    # Use a dot boundary, so slot 1 never includes slot 2 or slot 3.
    return {key: value for key, value in family_snapshot(user_data).items()
            if key != prefix and not key.startswith(prefix + '.')}


def launch_player(binary: Path, log: Path, timeout: float, cwd: Path,
                  env: dict, slot: int, run_checked, *, new_game: bool = False) -> None:
    command = [str(binary), '--headless', '--verbose', '--max-fps', '60', '--quit-after', '1200']
    options = [f'--save-slot={slot}'] if slot != 1 else []
    if new_game:
        options.append('--new-game')
    if options:
        command += ['--', *options]
    run_checked(command, log, timeout=timeout, cwd=cwd, env=env)


def smoke_save_contract(binary: Path, logs: Path, timeout: float, run_checked) -> dict:
    """Test all three slots, two damaged cases and a surviving healthy slot.

    The strict caller owns per-process timeouts and engine diagnostics. The
    original first-start/resume smoke gate is retained and runs separately.
    """
    with tempfile.TemporaryDirectory(prefix='pilgrimage-save-contract-') as temporary:
        isolated = Path(temporary)
        user_data = isolated / 'user-data'
        env = dict(os.environ, XDG_DATA_HOME=str(user_data), APPDATA=str(user_data),
                   LOCALAPPDATA=str(isolated / 'local-data'), XDG_CONFIG_HOME=str(isolated / 'config'),
                   XDG_CACHE_HOME=str(isolated / 'cache'), GODOT_SILENCE_ROOT_WARNING='1')
        saves: dict[int, Path] = {}
        observed: dict[int, dict] = {}
        launches = []
        for slot in SAVE_NAMES:
            # Starting another slot may not touch any previously observed file.
            before = family_snapshot(user_data)
            label = f'slot-{slot}-first-start'
            launch_player(binary, logs / f'{label}.log', timeout, isolated, env, slot, run_checked)
            launches.append(label)
            save = locate_save(user_data, slot)
            saves[slot] = save
            ensure_unchanged(before, sibling_snapshot(user_data, save), f'Slot {slot} first start')
            data = read_save(save)
            if data['story_flags'].get(PROBE_FLAG) or any(data['story_flags'].get(f'{PROBE_FLAG}_{i}') for i in SAVE_NAMES):
                raise ValueError(f'Slot {slot} inherited another slot probe')
            # Only valid scalar currency and a harmless boolean flag are changed.
            # Inventory and build evidence are captured from the actual player.
            data['currency'] = 137 * slot
            data['story_flags'][f'{PROBE_FLAG}_{slot}'] = True
            save.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')
            backup = save.with_name(save.name + '.bak')
            backup.unlink(missing_ok=True)
            siblings = sibling_snapshot(user_data, save)
            expected = progress(data)
            label = f'slot-{slot}-resume'
            launch_player(binary, logs / f'{label}.log', timeout, isolated, env, slot, run_checked)
            launches.append(label)
            ensure_unchanged(siblings, sibling_snapshot(user_data, save), f'Slot {slot} resume')
            current = read_save(save)
            if progress(current) != expected:
                raise ValueError(f'Slot {slot} did not preserve its exact resume progress')
            if progress(read_save(backup)) != expected:
                raise ValueError(f'Slot {slot} did not write a verified resume backup')
            observed[slot] = current

        # A valid backup is offered through settings; it must not silently
        # replace a damaged primary or start a new writable journey.
        first = saves[1]
        first.write_bytes(b'{"version":3, "interrupted":')
        before = family_snapshot(user_data)
        label = 'damaged-primary-valid-backup'
        launch_player(binary, logs / f'{label}.log', timeout, isolated, env, 1, run_checked)
        launches.append(label)
        ensure_unchanged(before, family_snapshot(user_data), 'Damaged primary with valid backup')

        # Valid JSON can still be invalid progress. A second damaged backup
        # may not turn that into a fresh save or erase either original.
        second = saves[2]
        damaged = dict(observed[2], currency=-1)
        second.write_text(json.dumps(damaged, ensure_ascii=False), encoding='utf-8')
        second.with_name(second.name + '.bak').write_bytes(b'broken backup\x00original evidence')
        before = family_snapshot(user_data)
        label = 'invalid-schema-damaged-backup'
        launch_player(binary, logs / f'{label}.log', timeout, isolated, env, 2, run_checked)
        launches.append(label)
        ensure_unchanged(before, family_snapshot(user_data), 'Invalid primary and backup')

        # Blocked journeys must remain isolated from a healthy third slot.
        third = saves[3]
        siblings = sibling_snapshot(user_data, third)
        third.with_name(third.name + '.bak').unlink()
        label = 'healthy-slot-after-damage'
        launch_player(binary, logs / f'{label}.log', timeout, isolated, env, 3, run_checked)
        launches.append(label)
        ensure_unchanged(siblings, sibling_snapshot(user_data, third), 'Healthy slot after damage')
        if progress(read_save(third)) != progress(observed[3]):
            raise ValueError('Healthy third slot lost progress after damaged-slot boots')
        if progress(read_save(third.with_name(third.name + '.bak'))) != progress(observed[3]):
            raise ValueError('Healthy third slot did not resume and write back after damage')

        # Explicit new-game is a different operation from failed resume. Verify
        # it archives the selected journey and preserves an older abandonment.
        previous = third.with_name(third.name + '.previous')
        earlier = b'earlier abandoned journey: preserve original bytes\x00'
        previous.write_bytes(earlier)
        original = third.read_bytes()
        siblings = sibling_snapshot(user_data, third)
        label = 'explicit-new-game-preserves-journeys'
        launch_player(binary, logs / f'{label}.log', timeout, isolated, env, 3, run_checked, new_game=True)
        launches.append(label)
        ensure_unchanged(siblings, sibling_snapshot(user_data, third), 'Explicit selected-slot new game')
        fresh = read_save(third)
        if any(fresh['story_flags'].get(f'{PROBE_FLAG}_{i}') for i in SAVE_NAMES) or fresh['currency'] == observed[3]['currency']:
            raise ValueError('Explicit new game did not create fresh selected-slot progress')
        if not previous.is_file() or previous.read_bytes() != original:
            raise ValueError('Explicit new game did not archive the selected journey verbatim')
        older = list(third.parent.glob(third.name + '.previous.earlier_*'))
        if len(older) != 1 or older[0].read_bytes() != earlier:
            raise ValueError('Explicit new game discarded an earlier abandoned journey')

        evidence = {'schema_version': 1, 'slots': list(SAVE_NAMES), 'launches': launches,
                    'resume_writebacks': 4, 'damaged_cases_preserved': 2, 'new_game_archives_preserved': 2,
                    'qualification': 'headless delivered-player disk contract; no UI recovery or full gameplay claim'}
        logs.mkdir(parents=True, exist_ok=True)
        (logs / 'save-contract.json').write_text(json.dumps(evidence, indent=2) + '\n', encoding='utf-8')
    print('RELEASE_SAVE_CONTRACT_PASS slots=3 resume_writebacks=4 damaged_cases_preserved=2 archives_preserved=2', flush=True)
    return evidence
