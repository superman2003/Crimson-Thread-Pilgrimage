"""Exercise cache identity and offline hydration with a real tiny LFS repo."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from lfs_cache import cache_key


class CacheIdentity(unittest.TestCase):
    def test_key_ignores_order_paths_duplicates_and_checkout_state(self):
        a, b = 'a' * 64, 'b' * 64
        first = json.dumps(dict(files=[dict(oid=a, name='godot/a.png', checkout=False), dict(oid=b, name='godot/b.png', checkout=False)]))
        second = json.dumps(dict(files=[dict(oid=b, name='renamed path.png', checkout=True), dict(oid=a, name='other.png', checkout=True), dict(oid=a, name='copy.png', checkout=False)]))
        self.assertEqual(cache_key(first), cache_key(second))
        self.assertEqual(cache_key(first)[1], 2)
        self.assertNotEqual(cache_key(first), cache_key(json.dumps(dict(files=[dict(oid=a)]))))

    def test_bad_listing_cannot_create_a_cache_key(self):
        for listing in (b'not-json', json.dumps(dict(files=[dict(oid='x' * 64)])), json.dumps(dict(files=[dict(oid='a' * 10)]))):
            with self.subTest(listing=listing), self.assertRaises(ValueError):
                cache_key(listing)

    def test_cached_object_hydrates_offline_and_key_survives_smudging(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            env = dict(os.environ, GIT_LFS_SKIP_SMUDGE='1')

            def git(*args):
                return subprocess.run(['git', *args], cwd=root, env=env, check=True, capture_output=True).stdout

            git('init', '-q')
            git('config', 'user.email', 'fixture@example.invalid')
            git('config', 'user.name', 'LFS cache fixture')
            git('lfs', 'install', '--local', '--skip-smudge')
            git('remote', 'add', 'origin', 'http://127.0.0.1:9/offline-cache-fixture')
            data = b'offline cached object\n' * 64
            oid = hashlib.sha256(data).hexdigest()
            pointer = f'version https://git-lfs.github.com/spec/v1\noid sha256:{oid}\nsize {len(data)}\n'
            (root / '.gitattributes').write_text('*.png filter=lfs diff=lfs merge=lfs -text\n', encoding='utf-8')
            assets = root / 'godot/assets'
            assets.mkdir(parents=True)
            image = assets / 'has space.png'
            image.write_text(pointer, encoding='utf-8', newline='\n')
            git('add', '.')
            git('-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'fixture pointers')
            listing = ['lfs', 'ls-files', '--long', '--json', '--include=godot/assets/**']
            before = cache_key(git(*listing))
            self.assertEqual(before[1], 1)
            self.assertEqual(cache_key(git('lfs', 'ls-files', '--long', '--json', '--include=unrelated/**'))[1], 0)
            obj = root / '.git/lfs/objects' / oid[:2] / oid[2:4] / oid
            obj.parent.mkdir(parents=True)
            obj.write_bytes(data)
            # The remote is unreachable: success requires reuse of the cache.
            git('lfs', 'pull', '--include=godot/assets/**')
            self.assertEqual(image.read_bytes(), data)
            self.assertEqual(cache_key(git(*listing)), before)


if __name__ == '__main__':
    unittest.main()
