#!/usr/bin/env python3
"""Strict story/UI gate, followed by the existing narrative transaction suites."""
import sys
from run_godot_regressions import SUCCESS_MARKERS, main

SUCCESS_MARKERS['narrative_closure'] = r'^NARRATIVE_CLOSURE checks=\d+ failures=0 orders=720$'
SUCCESS_MARKERS['narrative_return_runtime'] = r'^NARRATIVE_RETURN_RUNTIME_PASS checks=\d+ failures=0$'
SUCCESS_MARKERS['npc_recollections'] = r'^NPC_RECOLLECTIONS checks=\d+ failures=0$'

if __name__ == '__main__':
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    if '--suite' not in sys.argv:
        for suite in ['narrative_closure', 'narrative_outcomes', 'narrative_return_runtime',
                      'tests/verify_world_narrative', 'tests/verify_narrative_ui',
                      'tests/verify_narrative_progression', 'tests/verify_narrative_runtime',
                      'ending_aftermath', 'npc_recollections']:
            sys.argv.extend(['--suite', suite])
    raise SystemExit(main())
