"""Validate NPC dialogue motion, real conversation UI and retained character art."""
from check_hero_motion_v8_native import main, ROOT

if __name__ == '__main__':
    raise SystemExit(main(default_suites=['npc_dialogue_motion', 'expanded_character_motion',
        'story_guidance', 'character_art_prewarm'],
        default_output=ROOT/'artifacts/npc_dialogue_motion_v10/final-native'))
