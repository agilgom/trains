import io
import json
import unittest
from unittest.mock import patch
from urllib.error import URLError

import server


class RenfeFeedTests(unittest.TestCase):
    def setUp(self):
        server._cache.update(body=None, expires=0.0)

    def test_valid_feed_is_cached(self):
        body = json.dumps({"header": {"timestamp": "123"}, "entity": []}).encode()
        with patch("server.urllib.request.urlopen", return_value=io.BytesIO(body)) as request:
            self.assertEqual(server.fetch_positions(), body)
            self.assertEqual(server.fetch_positions(), body)
            self.assertEqual(request.call_count, 1)

    def test_invalid_feed_is_not_cached(self):
        with patch("server.urllib.request.urlopen", return_value=io.BytesIO(b"{}")):
            with self.assertRaisesRegex(ValueError, "header"):
                server.fetch_positions()
        self.assertIsNone(server._cache["body"])

    def test_expired_cache_does_not_hide_upstream_failure(self):
        server._cache.update(body=b"old", expires=0)
        with patch("server.urllib.request.urlopen", side_effect=URLError("offline")):
            with self.assertRaises(URLError):
                server.fetch_positions()

    def test_feed_size_limit(self):
        with patch("server.urllib.request.urlopen",
                   return_value=io.BytesIO(b" " * (server.MAX_FEED_BYTES + 1))):
            with self.assertRaisesRegex(ValueError, "size limit"):
                server.fetch_positions()


if __name__ == "__main__":
    unittest.main()
