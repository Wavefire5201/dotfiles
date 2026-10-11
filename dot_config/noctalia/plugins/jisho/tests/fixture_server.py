"""Serves saved Jisho API responses for the QML harness.

Prints the bound port on stdout. GET /__log returns the keywords requested so far.
Special keywords: boom (HTTP 500), flaky (500 once, then 食べる), slow (1.5 s delay),
garbage (200 with an HTML body). Anything unknown gets the empty result.
"""

import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

FIXTURES = Path(__file__).resolve().parent / "fixtures"
KEYWORDS = {"食べる": "taberu", "neko": "neko", "eat": "eat", "ありがとう": "arigatou", "slow": "neko"}
log: list[str] = []
flaky_failed = False


class Handler(BaseHTTPRequestHandler):
    def send(self, status: int, body: bytes, ctype: str = "application/json") -> None:
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        global flaky_failed
        url = urlparse(self.path)
        if url.path == "/__log":
            return self.send(200, json.dumps(log, ensure_ascii=False).encode())
        keyword = parse_qs(url.query).get("keyword", [""])[0]
        log.append(keyword)
        if keyword == "boom":
            return self.send(500, b"{}")
        if keyword == "garbage":
            return self.send(200, b"<html>maintenance</html>", "text/html")
        if keyword == "flaky":
            if not flaky_failed:
                flaky_failed = True
                return self.send(500, b"{}")
            keyword = "食べる"
        if keyword == "slow":
            time.sleep(1.5)
        name = KEYWORDS.get(keyword, "none")
        self.send(200, (FIXTURES / f"{name}.json").read_bytes())

    def log_message(self, *args) -> None:
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
print(server.server_address[1], flush=True)
try:
    server.serve_forever()
except KeyboardInterrupt:
    sys.exit(0)
