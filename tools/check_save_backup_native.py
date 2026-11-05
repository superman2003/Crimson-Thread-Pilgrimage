"""Verify source-only backup preparation and the existing save/arrival contracts."""
from pathlib import Path
from check_hero_motion_v8_native import main

if __name__ == '__main__':
    raise SystemExit(main(
        ['world_save_backup', 'world_async_loading', 'world_save_candidate',
         'save_recovery', 'world_state', 'world_prepare_budget'],
        Path(__file__).resolve().parents[1]/'artifacts/save_backup_preparation_v14/final-native'))
