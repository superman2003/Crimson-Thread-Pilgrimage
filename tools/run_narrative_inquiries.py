#!/usr/bin/env python3
"""Strict shared runner for optional questions; errors and timeouts fail."""
import sys
from run_godot_regressions import SUCCESS_MARKERS, main

SUCCESS_MARKERS['narrative_inquiries'] = r'^NARRATIVE_INQUIRIES_PASS checks=\d+ failures=0$'
if __name__ == '__main__':
    if '--suite' not in sys.argv:
        sys.argv.extend(['--suite', 'narrative_inquiries'])
    raise SystemExit(main())
