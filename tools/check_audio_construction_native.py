"""Check staged audio ownership, actual World cancellation and existing audio gates."""
from pathlib import Path
from check_hero_motion_v8_native import main

if __name__ == '__main__':
    raise SystemExit(main(
        ['audio_construction', 'world_async_loading', 'world_prepare_budget',
         'world_save_backup', 'item_art_prewarm',
         'audio_retirement', 'audio_landmarks'],
        Path(__file__).resolve().parents[1]/'artifacts/audio_preparation_retirement_v22/final-native'))
