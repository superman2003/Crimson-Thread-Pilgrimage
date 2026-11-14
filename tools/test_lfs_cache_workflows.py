"""Keep cached hydration mandatory and downloads out of static-only CI jobs."""
from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]


def workflow(name):
    return yaml.safe_load((ROOT / '.github/workflows' / name).read_text(encoding='utf-8'))


class CachedHydrationWorkflows(unittest.TestCase):
    def test_restore_hydrate_save_order_and_failure_behavior(self):
        action = yaml.safe_load((ROOT / '.github/actions/hydrate-lfs/action.yml').read_text(encoding='utf-8'))
        steps = action['runs']['steps']
        restore, = [s for s in steps if s.get('uses') == 'actions/cache/restore@v4']
        hydrate, = [s for s in steps if 'tools/hydrate_runtime_assets.py' in s.get('run', '')]
        save, = [s for s in steps if s.get('uses') == 'actions/cache/save@v4']
        self.assertLess(steps.index(restore), steps.index(hydrate))
        self.assertLess(steps.index(hydrate), steps.index(save))
        self.assertNotIn('if', hydrate)  # Exact cache hits still hydrate the current pointers.
        self.assertNotIn('always()', save['if'])  # Failed hydration cannot save a new cache.
        self.assertNotIn('github.event_name', save['if'])  # Successful PRs can reuse their downloads.
        for step in (restore, save):
            self.assertEqual(step['with']['path'], '.git/lfs/objects')
        self.assertIn('lfs-v1-', restore['with']['restore-keys'])

    def test_both_integration_jobs_restore_before_downloading(self):
        for name, job in workflow('godot-integration.yml')['jobs'].items():
            with self.subTest(job=name):
                steps = job['steps']
                cached, = [s for s in steps if s.get('uses') == './.github/actions/hydrate-lfs']
                self.assertEqual(steps.index(cached), 1)
                checkout = steps[0]['run']
                self.assertIn('GIT_LFS_SKIP_SMUDGE=1 git fetch --depth=1', checkout)
                self.assertIn('GIT_LFS_SKIP_SMUDGE=1 git checkout --detach FETCH_HEAD', checkout)
                self.assertNotIn('git lfs pull', checkout)
                self.assertNotIn('hydrate_runtime_assets.py', checkout)
                self.assertIn('godot/assets/**', cached['with']['include'])

    def test_contracts_keep_the_selected_shards_required_assets(self):
        steps = workflow('contracts.yml')['jobs']['run']['steps']
        cached, = [s for s in steps if s.get('uses') == './.github/actions/hydrate-lfs']
        self.assertEqual(cached['with']['include'], '${{ steps.needs.outputs.lfs }}')
        self.assertEqual(cached['if'], "steps.needs.outputs.lfs != ''")
        self.assertLess(steps.index(cached), next(i for i, s in enumerate(steps) if 'tools/ci/contracts.py run' in s.get('run', '')))

    def test_static_jobs_do_not_download_assets_native_jobs_still_hydrate(self):
        for name in ('material-conversion-plan-wip.yml', 'settings-dialog-layout.yml'):
            jobs = workflow(name)['jobs']
            for key, job in jobs.items():
                with self.subTest(workflow=name, job=key):
                    steps = job['steps']
                    self.assertFalse(steps[0]['with']['lfs'])
                    cached = [s for s in steps if s.get('uses') == './.github/actions/hydrate-lfs']
                    if key == 'static-gates':
                        self.assertFalse(cached)
                        self.assertIn('npm test', steps[-1]['run'])
                    else:
                        self.assertEqual(len(cached), 1)
                        self.assertEqual(cached[0]['with']['include'], 'godot/**')


if __name__ == '__main__':
    unittest.main()
