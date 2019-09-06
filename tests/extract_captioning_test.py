import unittest
from sentence_splitting import extract_captioning


class ExtractCaptioningTest(unittest.TestCase):
    def test_complete(self):
        text = ["Captioning sponsored by CBS", ">> HI, STEPHEN."]
        text, captioning_tag = extract_captioning(text)
        print(captioning_tag)
        self.assertEqual([">> HI, STEPHEN."], text)
        self.assertEqual('<meta type="caption_credits" value="Captioning sponsored by CBS"/>', captioning_tag)

    def test_ends_with_by(self):
        text = ["Captioning sponsored by", "CBS", ">> HI, STEPHEN."]
        text, captioning_tag = extract_captioning(text)
        print(captioning_tag)
        self.assertEqual([">> HI, STEPHEN."], text)
        self.assertEqual('<meta type="caption_credits" value="Captioning sponsored by CBS"/>', captioning_tag)

    def test_next_line_and(self):
        text = ["Captioning funded by CBS", "and Ford.", ">> Whitaker: THIS WAS THE FIRST"]
        text, captioning_tag = extract_captioning(text)
        print(captioning_tag)
        self.assertEqual([">> Whitaker: THIS WAS THE FIRST"], text)
        self.assertEqual('<meta type="caption_credits" value="Captioning funded by CBS and Ford."/>', captioning_tag)

    def test_in_story(self):
        text = ["It was a weird Captioning", " blabla.", ">> Whitaker: THIS WAS THE FIRST"]
        text, captioning_tag = extract_captioning(text)
        print(captioning_tag)
        self.assertEqual(["It was a weird Captioning", " blabla.", ">> Whitaker: THIS WAS THE FIRST"], text)
        self.assertEqual(None, captioning_tag)

    def test_with_web_address(self):
        text = ["Captioning funded by CBS", "and Ford.", "cbs.ford.de", ">> Whitaker: THIS WAS THE FIRST"]
        text, captioning_tag = extract_captioning(text)
        print(captioning_tag)
        self.assertEqual([">> Whitaker: THIS WAS THE FIRST"], text)
        self.assertEqual('<meta type="caption_credits" value="Captioning funded by CBS and Ford. cbs.ford.de"/>', captioning_tag)


if __name__ == '__main__':
    unittest.main()
