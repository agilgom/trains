#!/usr/bin/env python3
"""Serve the map and proxy Renfe's public GTFS-Realtime position feed."""

import json
import threading
import time
import urllib.error
import urllib.request
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


FEED_URL = "https://gtfsrt.renfe.com/vehicle_positions_LD.json"
FEED_PATH = "/api/renfe/vehicles"
CACHE_SECONDS = 30
MAX_FEED_BYTES = 5 * 1024 * 1024
OUTPUT_DIR = Path(__file__).resolve().parent / "docs"
_cache_lock = threading.Lock()
_cache = {"body": None, "expires": 0.0}


def fetch_positions():
    with _cache_lock:
        if _cache["body"] is not None and time.monotonic() < _cache["expires"]:
            return _cache["body"]

        request = urllib.request.Request(
            FEED_URL, headers={"User-Agent": "USGeographyRailwaysMap/1.0"}
        )
        with urllib.request.urlopen(request, timeout=15) as response:
            body = response.read(MAX_FEED_BYTES + 1)
        if len(body) > MAX_FEED_BYTES:
            raise ValueError("Renfe feed exceeds the size limit")
        feed = json.loads(body)
        if not isinstance(feed, dict) or not isinstance(feed.get("header"), dict):
            raise ValueError("Renfe feed is missing its header")
        if not isinstance(feed.get("entity"), list):
            raise ValueError("Renfe feed is missing its entity list")
        _cache.update(body=body, expires=time.monotonic() + CACHE_SECONDS)
        return body


class MapHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if urlsplit(self.path).path != FEED_PATH:
            return super().do_GET()
        try:
            body = fetch_positions()
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as error:
            self.log_error("Renfe feed unavailable: %s", error)
            body = json.dumps({"error": "Renfe feed unavailable"}).encode("utf-8")
            self.send_response(502)
        else:
            self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def main():
    if not (OUTPUT_DIR / "us_geography_railways.html").is_file():
        raise SystemExit("Generate the map first with python3 generate_map.py")
    server = ThreadingHTTPServer(
        ("127.0.0.1", 8000), partial(MapHandler, directory=str(OUTPUT_DIR))
    )
    print("Map: http://127.0.0.1:8000/us_geography_railways.html", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping map server.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
