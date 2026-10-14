"""Negative checks for the pack boundary and offline catalog generation."""
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import threading
import unittest
import urllib.request
import urllib.error

SPEC = importlib.util.spec_from_file_location("review_builder", Path(__file__).with_name("build_review.py"))
builder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)
SERVER_SPEC = importlib.util.spec_from_file_location("review_server", Path(__file__).with_name("serve_review.py"))
server_module = importlib.util.module_from_spec(SERVER_SPEC)
SERVER_SPEC.loader.exec_module(server_module)


class ReviewBuilderChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.pack = self.root / "assets/proposals/reverse_motion_v2"
        self.pack.mkdir(parents=True)
        # Header-only fixture for dimension checks, not presented as a decodable PNG.
        (self.pack / "atlas.png").write_bytes(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 256, 128))
        self.item = {"id":"crimson_attack", "title":"针击", "type":"animation", "file":"atlas.png",
                     "frame_width":128,"frame_height":128,"frame_count":2,"columns":2,"fps":12,"loop":False,
                     "events":[{"frame":1,"name":"接触"}]}
        self.manifest = {"schema_version":1,"pack_id":"reverse_motion_v2","title":"动作", "items":[self.item]}

    def tearDown(self):
        self.temp.cleanup()

    def read(self):
        (self.pack / "manifest.json").write_text(json.dumps(self.manifest), encoding="utf-8")
        return builder.read_pack(self.root, "reverse_motion_v2")

    def test_valid_animation_preserves_timing_and_files(self):
        pack, files = self.read()
        self.assertEqual(pack["items"][0]["events"], self.item["events"])
        self.assertEqual(len(files), 2)
        self.assertTrue(pack["items"][0]["url"].endswith("/reverse_motion_v2/atlas.png"))

    def test_parent_escape_rejected(self):
        self.item["file"] = "../atlas.png"
        with self.assertRaisesRegex(ValueError, "escapes pack"):
            self.read()

    def test_symlink_to_outside_rejected(self):
        external = self.root / "outside.png"
        external.write_bytes((self.pack / "atlas.png").read_bytes())
        (self.pack / "link.png").symlink_to(external)
        self.item["file"] = "link.png"
        with self.assertRaisesRegex(ValueError, "Symlink"):
            self.read()

    def test_lfs_pointer_rejected(self):
        (self.pack / "atlas.png").write_text("version https://git-lfs.github.com/spec/v1\noid sha256:abc\nsize 10\n")
        with self.assertRaisesRegex(ValueError, "LFS pointer"):
            self.read()

    def test_atlas_size_mismatch_rejected(self):
        self.item["frame_count"] = 3
        with self.assertRaisesRegex(ValueError, "Atlas dimensions"):
            self.read()

    def test_duplicate_id_rejected(self):
        self.manifest["items"].append(dict(self.item))
        with self.assertRaisesRegex(ValueError, "Duplicate item"):
            self.read()

    def test_contact_beyond_last_frame_rejected(self):
        self.item["events"][0]["frame"] = 2
        with self.assertRaisesRegex(ValueError, "event outside"):
            self.read()

    def test_nonfinite_timing_rejected(self):
        self.item["fps"] = float("nan")
        with self.assertRaisesRegex(ValueError, "Invalid fps"):
            self.read()

    def test_external_svg_reference_rejected(self):
        path = self.pack / "layer.svg"
        path.write_text('<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/a.png"/></svg>')
        with self.assertRaisesRegex(ValueError, "external"):
            builder.check_svg(path)

    def test_internal_svg_gradient_allowed(self):
        path = self.pack / "layer.svg"
        path.write_text('<svg xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g"/></defs><rect fill="url(#g)"/></svg>')
        builder.check_svg(path)

    def test_scripted_svg_rejected(self):
        path = self.pack / "layer.svg"
        path.write_text('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>')
        with self.assertRaisesRegex(ValueError, "Active SVG"):
            builder.check_svg(path)

    def test_media_byte_ranges_and_invalid_range(self):
        server = server_module.make_server(self.root, 0)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        url = f"http://127.0.0.1:{server.server_port}/assets/proposals/reverse_motion_v2/atlas.png"
        expected = (self.pack / "atlas.png").read_bytes()
        try:
            for header, data in [("bytes=0-7", expected[:8]), ("bytes=-5", expected[-5:]), ("bytes=10-", expected[10:])]:
                request = urllib.request.Request(url, headers={"Range":header})
                with urllib.request.urlopen(request) as response:
                    self.assertEqual(response.status, 206)
                    self.assertEqual(response.read(), data)
                    self.assertEqual(response.headers["Accept-Ranges"], "bytes")
            with self.assertRaises(urllib.error.HTTPError) as error:
                urllib.request.urlopen(urllib.request.Request(url, headers={"Range":"bytes=999-"}))
            self.assertEqual(error.exception.code, 416)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_head_ignores_range(self):
        server = server_module.make_server(self.root, 0)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        url = f"http://127.0.0.1:{server.server_port}/assets/proposals/reverse_motion_v2/atlas.png"
        expected_size = (self.pack / "atlas.png").stat().st_size
        try:
            for header in (None, "bytes=0-7", "bytes=999-"):
                with self.subTest(range=header):
                    headers = {"Range": header} if header else {}
                    request = urllib.request.Request(url, headers=headers, method="HEAD")
                    with urllib.request.urlopen(request) as response:
                        self.assertEqual(response.status, 200)
                        self.assertEqual(response.headers["Content-Length"], str(expected_size))
                        self.assertIsNone(response.headers.get("Content-Range"))
                        self.assertEqual(response.read(), b"")
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_directory_index_symlink_outside_root_rejected(self):
        server = server_module.make_server(self.root, 0)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        directory = self.root / "review"
        directory.mkdir()
        url = f"http://127.0.0.1:{server.server_port}/review/"
        try:
            with tempfile.TemporaryDirectory() as external_dir:
                external = Path(external_dir) / "outside.html"
                external.write_text("outside repository", encoding="utf-8")
                for name in ("index.html", "index.htm"):
                    index = directory / name
                    index.symlink_to(external)
                    for method in ("GET", "HEAD"):
                        for header in (None, "bytes=0-7"):
                            with self.subTest(index=name, method=method, range=header):
                                headers = {"Range": header} if header else {}
                                request = urllib.request.Request(url, headers=headers, method=method)
                                with self.assertRaises(urllib.error.HTTPError) as error:
                                    urllib.request.urlopen(request)
                                self.assertEqual(error.exception.code, 403)
                                error.exception.close()
                    index.unlink()
                # Ordinary in-root indexes still use the standard handler.
                (directory / "index.html").write_text("review index", encoding="utf-8")
                with urllib.request.urlopen(url) as response:
                    self.assertEqual(response.status, 200)
                    self.assertEqual(response.read(), b"review index")
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == "__main__":
    unittest.main()
