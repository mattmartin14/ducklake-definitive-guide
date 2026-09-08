#!/usr/bin/env python3
"""Static file server with HTTP Range support for the DuckDB-WASM + Mosaic demo.

DuckDB-Wasm's httpfs implementation reads Parquet files with byte-range
requests, so a plain http.server (which ignores the Range header) is not
enough. This server implements 206 Partial Content responses.

It also proxies POST /quack requests to the local Quack sidecar
(start_quack_sidecar.sh) so the browser's Quack traffic stays same-origin
with this server, which sidesteps CORS entirely instead of requiring the
Quack server itself to send CORS headers.
"""

from __future__ import annotations

import http.client
import os
import re
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

RANGE_RE = re.compile(r"bytes=(\d*)-(\d*)")
QUACK_PROXY_HOST = os.getenv("QUACK_HOST", "127.0.0.1")
QUACK_PROXY_PORT = int(os.getenv("QUACK_PORT", "9494"))


class RangeRequestHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def send_head(self):
        path = self.translate_path(self.path)
        if os.path.isdir(path):
            return super().send_head()
        if not os.path.exists(path):
            self.send_error(404, "File not found")
            return None

        file_size = os.path.getsize(path)
        range_header = self.headers.get("Range")

        if not range_header:
            f = open(path, "rb")
            self.send_response(200)
            self.send_header("Content-Type", self.guess_type(path))
            self.send_header("Content-Length", str(file_size))
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
            self.send_header("Pragma", "no-cache")
            self.end_headers()
            return f

        match = RANGE_RE.match(range_header)
        if not match:
            self.send_error(416, "Invalid Range header")
            return None

        start_str, end_str = match.groups()
        start = int(start_str) if start_str else 0
        end = int(end_str) if end_str else file_size - 1
        end = min(end, file_size - 1)

        if start > end or start >= file_size:
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{file_size}")
            self.end_headers()
            return None

        length = end - start + 1
        f = open(path, "rb")
        f.seek(start)

        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(path))
        self.send_header("Content-Length", str(length))
        self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.end_headers()

        self._range_start = start
        self._range_length = length
        return f

    def copyfile(self, source, outputfile):
        length = getattr(self, "_range_length", None)
        if length is None:
            return super().copyfile(source, outputfile)

        remaining = length
        chunk_size = 64 * 1024
        while remaining > 0:
            chunk = source.read(min(chunk_size, remaining))
            if not chunk:
                break
            outputfile.write(chunk)
            remaining -= len(chunk)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def do_POST(self):
        if self.path != "/quack":
            self.send_error(404, "Not found")
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length else b""

        forward_headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in ("host", "content-length")
        }
        forward_headers["Content-Length"] = str(len(body))

        conn = http.client.HTTPConnection(QUACK_PROXY_HOST, QUACK_PROXY_PORT)
        try:
            conn.request("POST", "/quack", body=body, headers=forward_headers)
            response = conn.getresponse()
            response_body = response.read()
        except ConnectionRefusedError:
            self.send_error(502, "Quack sidecar is not running (see start_quack_sidecar.sh)")
            return
        finally:
            conn.close()

        self.send_response(response.status)
        for key, value in response.getheaders():
            if key.lower() in ("transfer-encoding", "connection"):
                continue
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(response_body)


def main() -> None:
    base_dir = Path(__file__).resolve().parent
    os.chdir(base_dir)

    port = int(os.getenv("PORT", "8000"))
    host = os.getenv("HOST", "127.0.0.1")

    print(f"Serving {base_dir} on http://{host}:{port}")
    print("Range requests are supported for DuckDB-WASM httpfs Parquet reads.")

    server = ThreadingHTTPServer((host, port), RangeRequestHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")


if __name__ == "__main__":
    main()
