"""Validate item atlas prewarming with production consumers and region loading."""
from check_hero_motion_v8_native import main, ROOT

if __name__ == '__main__':
    raise SystemExit(main(default_suites=['item_art_prewarm', 'world_async_loading',
        'pickup_ledger', 'character_art_prewarm', 'ui_text_order'],
        default_output=ROOT/'artifacts/item_art_prewarm/native'))
