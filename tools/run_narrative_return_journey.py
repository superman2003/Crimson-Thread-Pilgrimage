#!/usr/bin/env python3
"""Focused narrative gate using the shared strict runner without editing its registry."""
import sys
from run_godot_regressions import SUCCESS_MARKERS, main

SUCCESS_MARKERS['narrative_return_runtime'] = r'^NARRATIVE_RETURN_RUNTIME_PASS checks=\d+ failures=0$'
if __name__ == '__main__':
    if '--suite' not in sys.argv:
        for suite in ['narrative_outcomes', 'narrative_return_runtime',
                      'tests/verify_world_narrative', 'tests/verify_narrative_ui',
                      'tests/verify_narrative_progression', 'tests/verify_narrative_runtime',
                      'build_transaction_runtime', 'seal_acquisition']:
            sys.argv.extend(['--suite', suite])
    raise SystemExit(main())
