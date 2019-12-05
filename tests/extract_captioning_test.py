import unittest
from sentence_splitting import extract_captioning, load_captioning_specials


class ExtractCaptioningTest(unittest.TestCase):

    def setUp(self) -> None:
        with open("../captioning_specials.tsv", "r") as f:
            self.specials = load_captioning_specials(f)

    def test_complete(self):
        text = ["Captioning sponsored by CBS", ">> HI, STEPHEN."]
        text, captioning_tag = extract_captioning(text, self.specials)
        self.assertEqual([">> HI, STEPHEN."], text)
        self.assertEqual('<meta type="caption_credits" value="Captioning sponsored by CBS"/>', captioning_tag)

    def test_ends_with_by(self):
        text = ["Captioning sponsored by", "CBS", ">> HI, STEPHEN."]
        text, captioning_tag = extract_captioning(text, self.specials)
        self.assertEqual([">> HI, STEPHEN."], text)
        self.assertEqual('<meta type="caption_credits" value="Captioning sponsored by CBS"/>', captioning_tag)

    def test_next_line_and(self):
        text = ["Captioning funded by CBS", "and Ford.", ">> Whitaker: THIS WAS THE FIRST"]
        text, captioning_tag = extract_captioning(text, self.specials)
        self.assertEqual([">> Whitaker: THIS WAS THE FIRST"], text)
        self.assertEqual('<meta type="caption_credits" value="Captioning funded by CBS and Ford."/>', captioning_tag)

    def test_in_story(self):
        text = ["It was a weird Captioning", " blabla.", ">> Whitaker: THIS WAS THE FIRST"]
        text, captioning_tag = extract_captioning(text, self.specials)
        self.assertEqual(["It was a weird Captioning", " blabla.", ">> Whitaker: THIS WAS THE FIRST"], text)
        self.assertEqual(None, captioning_tag)

    def test_with_web_address(self):
        text = ["Captioning funded by CBS", "and Ford.", "      cbs.ford.de", ">> Whitaker: THIS WAS THE FIRST"]
        text, captioning_tag = extract_captioning(text, self.specials)
        self.assertEqual([">> Whitaker: THIS WAS THE FIRST"], text)
        self.assertEqual('<meta type="caption_credits" value="Captioning funded by CBS and Ford. cbs.ford.de"/>',
                         captioning_tag)

    def test_specials(self):
        text = ["Captioning sponsored by", "CBS", "       C.S.I. PRODUCTIONS", "  and brought to you by Toyota.",
                "         Moving Forward.", ">> Whitaker: THIS WAS THE FIRST"]
        text, captioning_tag = extract_captioning(text, self.specials)
        self.assertEqual([">> Whitaker: THIS WAS THE FIRST"], text)
        self.assertEqual('<meta type="caption_credits" value="Captioning sponsored by CBS C.S.I. PRODUCTIONS '
                         'and brought to you by Toyota. Moving Forward."/>', captioning_tag)

        text = ["Captioning founded by CBS", "and FORD.", "We go further, so you can.",
                ">> Whitaker: THIS WAS THE FIRST"]
        text, captioning_tag = extract_captioning(text, self.specials)
        self.assertEqual([">> Whitaker: THIS WAS THE FIRST"], text)
        self.assertEqual('<meta type="caption_credits" value="Captioning founded by CBS and FORD. '
                         'We go further, so you can."/>', captioning_tag)

        text = ["[captioning made possible by fox broadcasting company]",
                "captioned by the national captioning institute", "-- www.ncicap.org --",
                ">> Whitaker: THIS WAS THE FIRST"]
        text, captioning_tag = extract_captioning(text, self.specials)
        self.assertEqual([">> Whitaker: THIS WAS THE FIRST"], text)
        self.assertEqual('<meta type="caption_credits" value="captioning made possible by fox broadcasting company '
                         'captioned by the national captioning institute -- www.ncicap.org --"/>', captioning_tag)

        text = ["captioning made possible by fox broadcasting company",
                ">> Whitaker: THIS WAS THE FIRST"]
        text, captioning_tag = extract_captioning(text, self.specials)
        self.assertEqual([">> Whitaker: THIS WAS THE FIRST"], text)
        self.assertEqual('<meta type="caption_credits" value="captioning made possible by fox broadcasting company"/>',
                         captioning_tag)

        text = ["captioning made possible by fox broadcasting company", "-- www.ncicap.org --",
                ">> Whitaker: THIS WAS THE FIRST"]
        text, captioning_tag = extract_captioning(text, self.specials)
        self.assertEqual([">> Whitaker: THIS WAS THE FIRST"], text)
        self.assertEqual('<meta type="caption_credits" value="captioning made possible by fox broadcasting company '
                         '-- www.ncicap.org --"/>', captioning_tag)


if __name__ == '__main__':
    unittest.main()
