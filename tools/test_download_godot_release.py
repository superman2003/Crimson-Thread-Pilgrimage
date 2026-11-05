"""Exercise transient HTTP failures and the actual archive installation boundary."""
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import json
from pathlib import Path
import ssl
import tempfile
import threading
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request
import zipfile

import download_godot_release as release


def digest(data):
    return hashlib.sha512(data).hexdigest()


def archive(entries):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w') as output:
        for name, content in entries.items():
            output.writestr(name, content)
    return stream.getvalue()


class ReleaseDownload(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.actions = {}
        cls.calls = {}

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                cls.calls[self.path] = cls.calls.get(self.path, 0)+1
                options = cls.actions.get(self.path, [(404, b'missing', {})])
                status, body, headers = options[min(cls.calls[self.path]-1, len(options)-1)]
                self.send_response(status)
                for name, value in {'Content-Length':str(len(body)), **headers}.items():
                    self.send_header(name, value)
                self.end_headers()
                self.wfile.write(body)
                self.close_connection = True

        cls.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f'http://127.0.0.1:{cls.server.server_port}/'

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=5)

    def setUp(self):
        self.actions.clear()
        self.calls.clear()
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.delays = []
        # These are real local HTTP requests, with host proxy settings excluded.
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        self.patch = patch('download_godot_release.urllib.request.urlopen', opener.open)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def fetch(self, expected, **kwargs):
        return release.download(self.base+'payload', self.root/'download', expected,
                                sleep=self.delays.append, **kwargs)

    def test_transient_http_504_and_503_then_success(self):
        self.actions['/payload'] = [(504,b'',{}), (503,b'',{}), (200,b'actual',{})]
        self.assertEqual(self.fetch(digest(b'actual')).read_bytes(), b'actual')
        self.assertEqual(self.calls['/payload'], 3)
        self.assertEqual(self.delays, [5,10])
        self.assertEqual(list(self.root.glob('*.part')), [])

    def test_permanent_error_is_not_retried(self):
        with self.assertRaises(urllib.error.HTTPError):
            self.fetch(digest(b'actual'))
        self.assertEqual(self.calls['/payload'], 1)
        self.assertEqual(self.delays, [])

    def eof_response(self, exception):
        class BrokenResponse:
            headers = {}

            def __enter__(self):
                return self

            def __exit__(self, *args):
                pass

            def read(self, _size):
                raise exception
        return BrokenResponse()

    def test_abrupt_tls_eof_during_body_read_is_retried(self):
        self.actions['/payload']=[(200,b'actual',{})]
        open_response=release.urllib.request.urlopen
        calls=[]

        def open_then_disconnect(*args, **kwargs):
            calls.append(args[0])
            if len(calls)==1:
                return self.eof_response(ssl.SSLEOFError(8,'abrupt TLS EOF'))
            return open_response(*args, **kwargs)

        with patch('download_godot_release.urllib.request.urlopen',side_effect=open_then_disconnect):
            self.assertEqual(self.fetch(digest(b'actual')).read_bytes(),b'actual')
        self.assertEqual(len(calls),2)
        self.assertEqual(self.delays,[5])
        self.assertEqual(list(self.root.glob('*.part')),[])

    def test_repeated_abrupt_tls_eof_is_bounded(self):
        with patch('download_godot_release.urllib.request.urlopen',
                   side_effect=lambda *a,**kw:self.eof_response(ssl.SSLEOFError(8,'abrupt TLS EOF'))) as opening:
            with self.assertRaisesRegex(RuntimeError,'after 2 attempts'):
                self.fetch(digest(b'actual'),attempts=2)
        self.assertEqual(opening.call_count,2)
        self.assertEqual(self.delays,[5])
        self.assertFalse((self.root/'download').exists())
        self.assertEqual(list(self.root.glob('*.part')),[])

    def test_certificate_failures_are_never_retried(self):
        certificate=ssl.SSLCertVerificationError(1,'certificate verification failed')
        with patch('download_godot_release.urllib.request.urlopen',
                   return_value=self.eof_response(certificate)) as opening:
            with self.assertRaises(ssl.SSLCertVerificationError):
                self.fetch(digest(b'actual'))
        self.assertEqual(opening.call_count,1)
        with patch('download_godot_release.urllib.request.urlopen',
                   side_effect=urllib.error.URLError(certificate)) as opening:
            with self.assertRaises(urllib.error.URLError):
                self.fetch(digest(b'actual'))
        self.assertEqual(opening.call_count,1)
        self.assertEqual(self.delays,[])
        self.assertEqual(list(self.root.glob('*.part')),[])

    def test_retry_limit_preserves_existing_destination(self):
        self.actions['/payload'] = [(504,b'',{})]
        (self.root/'download').write_bytes(b'previous')
        with self.assertRaisesRegex(RuntimeError, 'after 3 attempts'):
            self.fetch(digest(b'actual'), attempts=3)
        self.assertEqual(self.calls['/payload'], 3)
        self.assertEqual((self.root/'download').read_bytes(), b'previous')
        self.assertEqual(list(self.root.glob('*.part')), [])

    def test_truncated_http_response_is_retried(self):
        self.actions['/payload'] = [(200,b'half',{'Content-Length':'20'}), (200,b'actual',{})]
        self.assertEqual(self.fetch(digest(b'actual')).read_bytes(), b'actual')
        self.assertEqual(self.calls['/payload'], 2)

    def test_wrong_hash_cannot_replace_previous_bytes(self):
        self.actions['/payload'] = [(200,b'corrupt',{})]
        (self.root/'download').write_bytes(b'previous')
        with self.assertRaisesRegex(RuntimeError, 'SHA512 mismatch'):
            self.fetch(digest(b'actual'), attempts=2)
        self.assertEqual((self.root/'download').read_bytes(), b'previous')
        self.assertEqual(list(self.root.glob('*.part')), [])

    def test_verified_cache_avoids_network(self):
        (self.root/'download').write_bytes(b'actual')
        self.assertEqual(self.fetch(digest(b'actual')).read_bytes(), b'actual')
        self.assertEqual(self.calls, {})

    def test_manifest_without_expected_hash_is_refetched(self):
        self.actions['/payload'] = [(200,b'fresh manifest',{})]
        (self.root/'download').write_bytes(b'old manifest')
        self.assertEqual(self.fetch(None).read_bytes(), b'fresh manifest')
        self.assertEqual(self.calls['/payload'], 1)

    def test_invalid_digest_or_attempts_is_rejected_before_network(self):
        for value in ['', 'abc', 'f'*127]:
            with self.assertRaises(ValueError):
                self.fetch(value)
        for value in [0, -1, True]:
            with self.assertRaises(ValueError):
                self.fetch(digest(b'actual'), attempts=value)
        self.assertEqual(self.calls, {})

    def test_manifest_rejects_empty_malformed_and_duplicate_entries(self):
        valid=digest(b'archive')+'  archive.zip\n'
        self.assertEqual(release.parse_checksums(valid), {'archive.zip':digest(b'archive')})
        for value in ['', 'not a manifest', valid+valid, digest(b'x')+'  ../archive.zip']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                release.parse_checksums(value)

    def prepare_install(self, template_entries=None, editor='Godot_v4.6.1-stable_linux.x86_64'):
        template=release.EDITORS[editor]
        editor_zip=archive({editor:b'editor executable','../escape':b'excluded'})
        templates=archive(template_entries if template_entries is not None else {'templates/'+template:b'release executable'})
        sums=f'{digest(editor_zip)}  {editor}.zip\n{digest(templates)}  {release.TEMPLATES}\n'.encode()
        for name, data in [('SHA512-SUMS.txt',sums), (editor+'.zip',editor_zip), (release.TEMPLATES,templates)]:
            self.actions['/'+name]=[(200,data,{})]
        return editor,template

    def install(self, editor, template):
        return release.install(editor,template,self.root/'engine',self.root/'templates',
                               self.root/'github-env',base=self.base,sleep=self.delays.append)

    def test_install_verifies_both_archives_and_exact_members_before_env(self):
        for selected in release.EDITORS:
            with self.subTest(editor=selected):
                editor,template=self.prepare_install(editor=selected)
                receipt=self.install(editor,template)
                self.assertEqual((self.root/'engine'/editor).read_bytes(), b'editor executable')
                self.assertEqual((self.root/'templates'/template).read_bytes(), b'release executable')
                self.assertFalse((self.root/'escape').exists())
                self.assertIn('GODOT=',(self.root/'github-env').read_text())
                self.assertEqual(json.loads((self.root/'engine/install-receipt.json').read_text()),receipt)
                self.assertEqual(receipt['binary_sha512'][template],digest(b'release executable'))

    def test_mismatched_editor_template_pair_is_rejected_before_network(self):
        with self.assertRaises(ValueError):
            self.install('Godot_v4.6.1-stable_linux.x86_64','windows_release_x86_64.exe')
        self.assertEqual(self.calls,{})

    def test_missing_selected_template_does_not_publish_env_or_stale_receipt(self):
        editor,template=self.prepare_install({'templates/unrelated':b'other'})
        (self.root/'engine').mkdir()
        (self.root/'engine/install-receipt.json').write_text('old successful receipt')
        with self.assertRaises(KeyError):
            self.install(editor,template)
        self.assertFalse((self.root/'github-env').exists())
        self.assertFalse((self.root/'engine/install-receipt.json').exists())
        self.assertEqual(list(self.root.rglob('*.part')),[])

    def test_missing_archive_checksum_is_not_downloaded_or_published(self):
        editor,template=self.prepare_install()
        self.actions['/SHA512-SUMS.txt']=[(200,(digest(b'x')+'  unrelated.zip\n').encode(),{})]
        with self.assertRaisesRegex(ValueError,'entry is missing'):
            self.install(editor,template)
        self.assertEqual(self.calls,{'/SHA512-SUMS.txt':1})
        self.assertFalse((self.root/'github-env').exists())

    def test_crc_failure_preserves_previous_extracted_binary(self):
        editor='Godot_v4.6.1-stable_linux.x86_64'
        payload=archive({editor:b'ORIGINAL'})
        payload=payload.replace(b'ORIGINAL',b'CORRUPTX',1)
        source=self.root/'corrupt.zip';source.write_bytes(payload)
        target=self.root/'binary';target.write_bytes(b'previous')
        with self.assertRaises(zipfile.BadZipFile):
            release.extract_member(source,editor,target)
        self.assertEqual(target.read_bytes(),b'previous')
        self.assertEqual(list(self.root.glob('*.part')),[])


if __name__ == '__main__':
    unittest.main()
