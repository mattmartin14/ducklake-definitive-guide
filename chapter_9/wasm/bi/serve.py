#!/usr/bin/env python3
"""Static file server + Quack proxy for the DuckDB-WASM sales portal.

Serves this directory's static files (index.html, app.js, etc.) and proxies
POST /quack requests to a local Quack endpoint (by default 127.0.0.1:9494,
which scripts/start_ssh_tunnel.sh forwards to the EC2-hosted Quack server).
Keeping the browser's Quack traffic same-origin avoids CORS entirely, since
there's no TLS/reverse proxy in front of the plain-HTTP Quack server.
"""

from __future__ import annotations

import http.client
import os
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

QUACK_PROXY_HOST = os.getenv("QUACK_HOST", "127.0.0.1")
QUACK_PROXY_PORT = int(os.getenv("QUACK_PORT", "9494"))


class Handler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
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
            self.send_error(
                502,
                "Quack is not reachable on "
                f"{QUACK_PROXY_HOST}:{QUACK_PROXY_PORT}. Is scripts/start_ssh_tunnel.sh running?",
            )
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
    print(f"Proxying POST /quack -> http://{QUACK_PROXY_HOST}:{QUACK_PROXY_PORT}/quack")

    server = ThreadingHTTPServer((host, port), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")


if __name__ == "__main__":
    main()
