#!/usr/bin/env python3
"""Local static server with runtime MD_TOKEN injection for DuckDB-WASM demo."""

from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/config.js":
            token = os.getenv("MD_TOKEN", "")
            body = f"window.APP_CONFIG = {json.dumps({'mdToken': token})};\n"
            encoded = body.encode("utf-8")

            self.send_response(200)
            self.send_header("Content-Type", "application/javascript; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)
            return

        super().do_GET()


def main():
    base_dir = Path(__file__).resolve().parent
    os.chdir(base_dir)

    port = int(os.getenv("PORT", "8000"))
    host = os.getenv("HOST", "127.0.0.1")

    print(f"Serving {base_dir} on http://{host}:{port}")
    print("MD_TOKEN is injected at runtime into /config.js")

    server = ThreadingHTTPServer((host, port), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")


if __name__ == "__main__":
    main()
