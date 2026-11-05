"""Native acceptance for complete-body idle, heavy cut and retained effects."""
from check_hero_motion_v8_native import main, ROOT, DEFAULT

if __name__ == '__main__':
    raise SystemExit(main(default_suites=['player_idle_motion','player_layered_idle',
        'player_motion_continuity',*DEFAULT],
        default_output=ROOT/'artifacts/hero_motion_v9/final-native'))
