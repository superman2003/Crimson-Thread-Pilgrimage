#!/usr/bin/env python3
"""Run isolated Godot suites; failures, engine errors and timeouts all fail CI."""
from __future__ import annotations
import argparse
import math
import json
from contextlib import contextmanager, nullcontext
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from software_gl import software_gl

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SUITES = (
    'world_rim world_wayfinding world_passage world_passage_network world_route_manifest_walk_lower world_route_manifest_walk_upper world_route_manifest_integration audio_retirement world_neighbor_collision world_neighbor_entities world_neighbor_gameplay world_gameplay_plan world_neighbor_gameplay_live world_neighbor_gameplay_stress terrain_collision_streaming world_platform_streaming cave_collision_streaming world_async_loading world_streaming world_host world_coordinates world_interaction_residency world_enemy_residency cartography world_map world_route_access world_state world_integration world_route_walk ability_movement '
    'character_art_prewarm texture_request_exit background_texture_contention expanded_character_motion enemy_lifecycle_regression enemy_effect_lifetime boss_skill_art combat_visual_budget enemy_visibility minor_enemy_skill_art enemy_atlas_integrity world_material hero_animation cave_exploration cave_route_walk '
    'chapter_route_regression ch01_room_reconstruction pilgrimage_merge_regression pilgrimage_review_regression '
    'all_chapters_demo pilgrimage_overhaul demo ch02_demo inventory_map boss_trial '
    'combat generated_runtime chapter_registry story_guidance chinese_story metsys '
    'permanent_capacity player_ability_art player_dash_art player_hook_art player_hurt_art player_movement_art player_heal_art player_guard_art player_upgrade_regression build_system world_upgrade world_workshop_group_one world_workshop_group_two world_ability_acquisition upgrade_integration save_product '
    'ui_build_accessibility ui_world_integration ui_redesign global_font ui_text_order '
    'seal_system seal_combat seal_ui seal_acceptance seal_acquisition seal_presentation seal_identity world_prepare_budget world_save_candidate map_player_pins world_preflight_budget world_config_background world_catalog_background world_startup_config_background world_neighbor_config world_resume_regression world_interaction_safety player_state_cleanup input_settings_regression input_prompt player_action_buffer player_motion_continuity player_layered_idle player_melee_feedback camera_focus room_camera_stability first_court_experience rain_foundry_experience salt_archive_experience greenhouse_experience obsidian_experience obsidian_road_clearance obsidian_dock_clearance crown_rain_slot '
    'world_startup_budget world_variant_copy survey_map_knowledge survey_room_segments ch06_workshop_experience silent_crown_experience optional_challenges world_death_cache_flush death_cache_placement g02_respawn '
    'melee_recovery spike_pogo combat_resource_cycle build_slots build_transaction_runtime enemy_encounter_roles enemy_ai_behavior enemy_tactical_roles build_slots_ui narrative_outcomes skill_branches artisan_crafts tool_practice shrine_exit_probe shrine_exit_routes hidden_routes save_recovery ending_aftermath settings_remap scene_history quiet_sole_traps wish_reward_atomic legacy_travel_rewards'
).split()
NARRATIVE_SUITES = ['tests/verify_world_narrative', 'tests/verify_narrative_ui', 'tests/verify_narrative_progression', 'tests/verify_narrative_runtime']
SUCCESS_MARKERS = json.loads((ROOT / 'tools/godot_suite_success_markers.json').read_text())

def suite_path(name):
    if not re.fullmatch(r'(?:tests/)?[a-z0-9_]+', name):
        raise ValueError(f'invalid suite name: {name}')
    return f'res://{name}.gd' if name.startswith('tests/') else f'res://scripts/{name}_validation.gd'

def render_loop_args(real_gl, suite):
    # These non-pixel suites keep physics/state checks. Keep the real GL
    # resource backend, but avoid automatic rasterization on every churn frame.
    # Dedicated GL pixel and live gameplay suites keep the render loop enabled.
    if real_gl and suite in ['world_upgrade', 'world_workshop_group_one', 'world_workshop_group_two', 'world_ability_acquisition', 'world_neighbor_gameplay_stress', 'world_passage_network']:
        return ['--disable-render-loop']
    return []

@contextmanager
def preserve_fixture_sources(suite):
    # This fault-injection suite changes the real manifest stamp/content. Restore
    # both even if Godot crashes, reports a script error, or exceeds its timeout.
    if suite != 'world_catalog_background':
        yield
        return
    path = ROOT / 'godot/data/world_routes.json'
    stamp = path.stat()
    content = path.read_bytes()
    try:
        yield
    finally:
        path.write_bytes(content)
        os.utime(path, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--suite', action='append', help='Repeat to select suites; defaults to the CI suite list.')
    parser.add_argument('--timeout', type=float, default=180)
    parser.add_argument('--log-dir', type=Path)
    parser.add_argument('--software-gl', action='store_true', help='Run all suites under real llvmpipe GL; avoids the Godot 4.6 dummy texture RID race without hiding errors.')
    args = parser.parse_args()
    engine = shutil.which(args.engine)
    if not engine:
        parser.error(f'Godot executable not found: {args.engine}; set GODOT or --engine')
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error('--timeout must be finite and positive')
    suites = args.suite or DEFAULT_SUITES + NARRATIVE_SUITES
    # Reject the whole request before running any suite or creating log files.
    try:
        for suite in suites:
            suite_path(suite)
    except ValueError as error:
        parser.error(str(error))
    failures = []
    with tempfile.TemporaryDirectory(prefix='pilgrimage-regressions-') as scratch:
        logs = args.log_dir or Path(scratch) / 'logs'
        logs.mkdir(parents=True, exist_ok=True)
        display = software_gl(logs / 'display') if args.software_gl else nullcontext({})
        with display as renderer_env:
            failures = run_suites(engine, suites, args.timeout, logs, Path(scratch), args.software_gl, renderer_env)
    print(f'GODOT_REGRESSIONS suites={len(suites)} failures={len(failures)}')
    return 1 if failures else 0


def run_suites(engine, suites, timeout, logs, scratch, real_gl, renderer_env):
    failures = []
    for suite in suites:
        script = suite_path(suite)
        name = suite.replace('/', '_')
        log = logs / f'{name}.log'
        if not (ROOT / 'godot' / script.removeprefix('res://')).is_file():
            failures.append(f'{suite}: missing validation script')
            print('FAIL: ' + failures[-1], flush=True)
            continue
        marker = SUCCESS_MARKERS.get(suite)
        if marker is None:
            failures.append(f'{suite}: missing completion marker contract')
            print('FAIL: ' + failures[-1], flush=True)
            continue
        env = dict(os.environ, **renderer_env, XDG_DATA_HOME=str(scratch / name))
        print(f'Running {suite}', flush=True)
        try:
            with preserve_fixture_sources(suite), log.open('w') as output:
                # Frame-counted ability/actuator and residency melee probes use a fixed clock.
                # Audio lifetime suites must retain normal playback timing.
                simulation = ['--fixed-fps', '60'] if suite in ['character_art_prewarm', 'expanded_character_motion', 'enemy_atlas_integrity', 'world_passage_network', 'world_route_manifest_walk_lower', 'world_route_manifest_walk_upper', 'ch06_workshop_experience', 'quiet_sole_traps wish_reward_atomic legacy_travel_rewards', 'melee_recovery', 'spike_pogo', 'combat_resource_cycle', 'build_transaction_runtime', 'enemy_encounter_roles', 'enemy_ai_behavior', 'build_slots_ui', 'skill_branches', 'artisan_crafts', 'tool_practice', 'shrine_exit_probe', 'shrine_exit_routes', 'hidden_routes', 'ending_aftermath', 'obsidian_experience', 'silent_crown_experience', 'optional_challenges', 'greenhouse_experience', 'salt_archive_experience', 'rain_foundry_experience', 'first_court_experience', 'camera_focus', 'room_camera_stability', 'player_action_buffer', 'player_motion_continuity', 'player_layered_idle', 'player_melee_feedback', 'ability_movement', 'world_upgrade', 'world_passage', 'world_neighbor_gameplay_live', 'world_enemy_residency', 'world_workshop_group_one', 'world_workshop_group_two', 'world_ability_acquisition'] else []
                # An intermittent CI shutdown leak needs the actual Resource
                # identity; verbose keeps that evidence without hiding errors.
                diagnostics = ['--verbose'] if suite in ['world_upgrade', 'world_workshop_group_one', 'world_workshop_group_two', 'world_enemy_residency', 'world_route_manifest_integration'] else []
                renderer = ['--display-driver', 'x11', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility'] if real_gl else ['--headless']
                drawing = render_loop_args(real_gl, suite)
                user_args = ['--', '--player'] if suite == 'room_camera_stability' else []
                result = subprocess.run([engine, *renderer, *drawing, *simulation, *diagnostics, '--path', str(ROOT / 'godot'), '--script', script, *user_args], env=env, stdout=output, stderr=subprocess.STDOUT, timeout=timeout, check=False)
            output = log.read_text(errors='replace')
            # Color must not hide fatal engine diagnostics or a valid marker.
            plain = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', output)
            errors = re.findall(r'^\s*(?:SCRIPT ERROR:|ERROR:).*$', plain, re.MULTILINE)
            completed = re.search(marker, plain, re.MULTILINE) is not None
            if result.returncode != 0 or errors or not completed:
                failures.append(f'{suite}: exit={result.returncode} engine_errors={len(errors)} completion_marker={completed}')
                print('FAIL: ' + failures[-1] + '\n' + '\n'.join(output.splitlines()[-40:]), flush=True)
            else:
                print('PASS: ' + suite + '\n' + '\n'.join(output.splitlines()[-2:]), flush=True)
        except subprocess.TimeoutExpired:
            failures.append(f'{suite}: timeout after {timeout:g}s')
            print('FAIL: ' + failures[-1], flush=True)
    return failures

if __name__ == '__main__':
    raise SystemExit(main())

