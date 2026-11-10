"""Run real NPC acting, portraits, voice mixing and the normal dialogue interface."""
from check_hero_motion_v8_native import main, ROOT

if __name__ == '__main__':
    raise SystemExit(main(default_suites=['npc_conversation_voice', 'npc_dialogue_motion', 'audio_retirement',
        'audio_construction', 'dialog_viewport_fit', 'story_guidance', 'expanded_character_motion'],
        default_output=ROOT/'artifacts/npc_insect_language_v1/native'))
