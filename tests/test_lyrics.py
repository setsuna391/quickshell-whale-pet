import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "current_lyric", Path(__file__).resolve().parents[1] / "tools/current-lyric.py")
lyrics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lyrics)


class LyricsTests(unittest.TestCase):
    def test_synced_line_uses_current_position(self):
        data = {"syncedLyrics": "[00:04.50] first\n[00:12.00] second\n"}
        self.assertEqual(lyrics.select_line(data, 10), "first")
        self.assertEqual(lyrics.select_line(data, 12), "second")
        self.assertEqual(lyrics.select_line(data, 1), "")

    def test_plain_lyrics_and_empty(self):
        self.assertEqual(lyrics.select_line({"plainLyrics": "\nonly line\n"}, 0), "only line")
        self.assertEqual(lyrics.select_line({}, 0), "")

    def test_netease_matches_title_and_all_artists(self):
        song = {"name": "A Song", "artists": [{"name": "One"}, {"name": "Two"}]}
        self.assertTrue(lyrics.netease_song_matches(song, "one,Two", "a song"))
        self.assertFalse(lyrics.netease_song_matches(song, "one,Other", "a song"))
        self.assertFalse(lyrics.netease_song_matches(song, "one", "another song"))


if __name__ == "__main__":
    unittest.main()
