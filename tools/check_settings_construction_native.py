"""Validate bounded settings construction, production controls and region loading."""
from check_hero_motion_v8_native import main, ROOT

if __name__ == '__main__':
    raise SystemExit(main(default_suites=['settings_construction_capture', 'settings_construction',
        'world_async_loading', 'ui_text_order', 'input_settings_regression',
        'settings_remap', 'controller_comfort'],
        default_output=ROOT/'artifacts/settings_construction_v12/native'))
