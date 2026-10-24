#!/usr/bin/env python3
"""Verify the ordinary PR222 dependency/main merge without relabeling old native evidence."""
import run_player_contact_art as evidence
ADDED = ['godot/scripts/pilgrimage_interface.gd', 'godot/scripts/build_system_validation.gd', 'godot/scripts/build_slots_ui_validation.gd', 'godot/scripts/legacy_travel_rewards_validation.gd', 'godot/scripts/quiet_sole_traps_validation.gd', 'godot/scripts/wish_reward_atomic_validation.gd', 'godot/tests/fixtures/quiet_sole_earned_return.json', 'godot/assets/ui/seals/damp_knot.svg', 'godot/assets/ui/seals/damp_knot.svg.import', 'godot/assets/ui/seals/quiet_sole.svg', 'tools/validate_seal_catalog.py', 'tools/run_player_contact_integration.py']
ADDED += ['godot/scripts/application_close.gd', 'godot/scripts/application_close_validation.gd', 'godot/scripts/crown_rain_slot_validation.gd', 'godot/scripts/world_crown_entry_playback.gd', 'godot/data/demo_ch06_silent_crown_core.json', 'tools/build_chapter_terrain.py']
evidence.SOURCES += ADDED
if __name__ == '__main__': evidence.main()
