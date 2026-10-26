import io
import os
import re
import unittest
from sentence_splitting import split_into_sentences, parse_capture_file, load_abbreviations


class TestMusicNotesSplitting(unittest.TestCase):
    def setUp(self):
        abbr_dir = os.path.join(os.path.dirname(__file__), "..", "nonbreaking_prefixes")
        self.abbreviations = load_abbreviations(os.path.abspath(abbr_dir))

    def test_music_line_starts_new_sentence(self):
        # Even without a period on the first line, musical notes should start a new sentence
        text = [
            "Coming up next on the news",
            "♪ ♪",
            "Welcome back to Eyewitness News"
        ]
        timestamps = [
            ["20160222160000.000", "20160222160002.000"],
            ["20160222160002.000", "20160222160004.000"],
            ["20160222160004.000", "20160222160006.000"]
        ]
        sentences = split_into_sentences(text, timestamps, self.abbreviations, {})
        assert len(sentences) == 3
        assert "Coming up next" in sentences[0]
        assert "♪ ♪" in sentences[1]
        assert "Welcome back" in sentences[2]

    def test_double_eighth_note_line(self):
        text = [
            "Special report continues",
            "♪♪ Music playing",
            "Report concludes."
        ]
        timestamps = [
            ["20160222160000.000", "20160222160002.000"],
            ["20160222160002.000", "20160222160004.000"],
            ["20160222160004.000", "20160222160006.000"]
        ]
        sentences = split_into_sentences(text, timestamps, self.abbreviations, {})
        assert len(sentences) == 3
        assert "Special report" in sentences[0]
        assert "♪♪ Music" in sentences[1]

    def test_bracketed_music_note(self):
        text = [
            "Story text here",
            "[♪ theme music ♪]",
            "Next story begins."
        ]
        timestamps = [
            ["20160222160000.000", "20160222160002.000"],
            ["20160222160002.000", "20160222160004.000"],
            ["20160222160004.000", "20160222160006.000"]
        ]
        sentences = split_into_sentences(text, timestamps, self.abbreviations, {})
        assert len(sentences) == 3
        assert "[♪ theme" in sentences[1]


class TestCommercialBreakSplitting(unittest.TestCase):
    def setUp(self):
        abbr_dir = os.path.join(os.path.dirname(__file__), "..", "nonbreaking_prefixes")
        self.abbreviations = load_abbreviations(os.path.abspath(abbr_dir))

    def test_commercial_break_force_split_with_millis(self):
        capture_data = (
            "TOP|20160222160000|2016-02-22_1600_US_KABC_News\n"
            "COL|Communication Studies Archive, UCLA\n"
            "UID|test-uid-123\n"
            "DUR|00:30:00\n"
            "VID|640x480\n"
            "20160222160000.000|20160222160003.000|CC1|News before commercial\n"
            "20160222160003.000|20160222160033.000|SEG_00|Type=Commercial\n"
            "20160222160004.000|20160222160008.000|CC1|Buy our product today\n"
            "20160222160033.000|20160222160100.000|SEG_00|Type=Story\n"
            "20160222160034.000|20160222160038.000|CC1|Welcome back to news\n"
            "END|\n"
        )
        file_obj = io.StringIO(capture_data)
        file_obj.name = "test_capture.txt"

        import sys
        old_stdout = sys.stdout
        sys.stdout = buffer = io.StringIO()
        try:
            parse_capture_file(file_obj, self.abbreviations, {})
        finally:
            sys.stdout = old_stdout

        output = buffer.getvalue()
        assert '<segment type="commercial">' in output
        assert "Buy our product today" in output
        assert "News before commercial" in output
        assert '<segment type="story">' in output

    def test_commercial_break_without_millis(self):
        # 14-digit timestamp without milliseconds
        capture_data = (
            "TOP|20160222160000|2016-02-22_1600_US_KABC_News\n"
            "COL|UCLA\n"
            "UID|test-uid-456\n"
            "DUR|00:30:00\n"
            "VID|640x480\n"
            "20160222160000|20160222160003|CC1|Lead story line\n"
            "20160222160003|20160222160033|SEG_00|Type=Commercial\n"
            "20160222160004|20160222160008|CC1|Car commercial ad\n"
            "END|\n"
        )
        file_obj = io.StringIO(capture_data)
        file_obj.name = "test_14digit.txt"

        import sys
        old_stdout = sys.stdout
        sys.stdout = buffer = io.StringIO()
        try:
            parse_capture_file(file_obj, self.abbreviations, {})
        finally:
            sys.stdout = old_stdout

        output = buffer.getvalue()
        assert '<segment type="commercial">' in output
        assert "Car commercial ad" in output
