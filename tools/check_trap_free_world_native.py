"""Verify trap-free chapters, retired entry points, rewards and normal combat."""
from check_hero_motion_v8_native import main, ROOT

if __name__ == '__main__':
    raise SystemExit(main(default_suites=['trap_free_world', 'quiet_sole_traps', 'spike_pogo',
        'legacy_travel_rewards', 'hazard_readability', 'player_contact_art', 'demo', 'ch02_demo',
        'build_slots_ui', 'loadout_restore_review'], default_output=ROOT/'artifacts/trap_free_world_v1/native',
        extra_markers={'loadout_restore_review': r'^LOADOUT_RESTORE_REVIEW checks=[1-9][0-9]* failures=0$'}))
