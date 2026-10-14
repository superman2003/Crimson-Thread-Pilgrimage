#!/usr/bin/env python3
"""Serve the offline review locally, with byte ranges for correct OGG seeking."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import os
import re

ROOT = Path(__file__).resolve().parents[3]


class RangeHandler(SimpleHTTPRequestHandler):
    def send_head(self):
        self.remaining = None
        path = Path(self.translate_path(self.path))
        root = Path(self.directory).resolve()
        if not path.resolve().is_relative_to(root):
            self.send_error(403, "Path outside repository")
            return None
        if path.is_dir():
            # The parent handler opens a directory's index without translating
            # its path again, so validate that final file before delegating.
            for name in getattr(self, "index_pages", ("index.html", "index.htm")):
                index = path / name
                if index.is_file():
                    if not index.resolve().is_relative_to(root):
                        self.send_error(403, "Path outside repository")
                        return None
                    break
        # Range applies only to GET; HEAD describes the complete resource.
        requested = self.headers.get("Range") if self.command == "GET" else None
        if not requested or path.is_dir():
            return super().send_head()
        try:
            stream = path.open("rb")
        except OSError:
            self.send_error(404, "File not found")
            return None
        size = os.fstat(stream.fileno()).st_size
        match = re.fullmatch(r"bytes=(\d*)-(\d*)", requested.strip())
        start, end = 0, size - 1
        if match and any(match.groups()):
            left, right = match.groups()
            if left:
                start = int(left)
                end = min(int(right), size - 1) if right else size - 1
            else:
                start = max(0, size - int(right))
        else:
            start = size
        if start >= size or start > end:
            stream.close()
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{size}")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return None
        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(str(path)))
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Length", str(end - start + 1))
        self.send_header("Last-Modified", self.date_time_string(os.fstat(stream.fileno()).st_mtime))
        self.end_headers()
        stream.seek(start)
        self.remaining = end - start + 1
        return stream

    def end_headers(self):
        self.send_header("Accept-Ranges", "bytes")
        super().end_headers()

    def copyfile(self, source, outputfile):
        if self.remaining is None:
            return super().copyfile(source, outputfile)
        remaining = self.remaining
        try:
            while remaining:
                block = source.read(min(64 * 1024, remaining))
                if not block:
                    break
                outputfile.write(block)
                remaining -= len(block)
        except (BrokenPipeError, ConnectionResetError):
            pass  # Switching tracks intentionally cancels the previous request.


def make_server(root: Path = ROOT, port: int = 8765):
    return ThreadingHTTPServer(("127.0.0.1", port), partial(RangeHandler, directory=str(root)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    with make_server(port=args.port) as server:
        print(f"http://127.0.0.1:{server.server_port}/docs/proposals/reverse_media_v2/", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
