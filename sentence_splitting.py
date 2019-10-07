#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import os
import os.path
import re
import sys
# import csv # Added by pgu
import pprint  # Added by pgu
from datetime import datetime, date, time, timedelta
from fuzzywuzzy import process as fuzzy


def command_line_arguments():
    """Create argparse object"""
    parser = argparse.ArgumentParser(description="Do sentence splitting on the given file.")
    parser.add_argument("-a", type=os.path.abspath, required=True,
                        help="Directory with abbreviation files of format .+\..{2} where the last two characters indicate a language")
    parser.add_argument("-c", type=argparse.FileType("r"), required=False,
                        help="File with special captioning lines")
    parser.add_argument("-l", type=str, help="Two-letter language code; defaults to 'en'")
    parser.add_argument("FILE", type=argparse.FileType("r"), help="Newsscape capture text file")
    args = parser.parse_args()
    return args


def xmlescape(x):
    x = re.sub(r'&', '&amp;', x);
    x = re.sub(r'"', '&quot;', x);
    x = re.sub(r'\'', '&apos;', x);
    x = re.sub(r'>', '&gt;', x);
    x = re.sub(r'<', '&lt;', x);
    return x


def xmlunescape(x):
    x = re.sub('&quot;', r'"', x);
    x = re.sub('&apos;', r'\'', x);
    x = re.sub('&gt;', r'>', x);
    x = re.sub('&lt;', r'<', x);
    x = re.sub('&amp;', r'&', x);
    return x


"""
def load_bracket_dictionary():
    dictionaries = ["round_brackets_dictionary.txt", "square_brackets_dictionary.txt"]
    bracket_dictionary = {}
    for dictionary in dictionaries:
        with open(dictionary, encoding='utf-8') as fh:
            for line in fh:
                line = line.strip();
                templist = line.split("\t")
                bracket_dictionary[templist.pop(0)] = templist
#    pp = pprint.PrettyPrinter(indent=4)
#    pp.pprint(bracket_dictionary)
    return bracket_dictionary

def load_words_with_colons_dictionary():
    dictionary = "words_with_colons_dictionary.txt"
    words_with_colons_dictionary = {}
    with open(dictionary, encoding='utf-8') as fh:
        for line in fh:
            line = line.strip();
            templist = line.split("\t")
            words_with_colons_dictionary[templist.pop(0)] = templist
#    pp = pprint.PrettyPrinter(indent=4)
#    pp.pprint(words_with_colons_)
    return words_with_colons_dictionary
"""


def load_abbreviations(directory):
    """Read in abbreviation files."""
    abbreviations = {}
    for filename in os.listdir(directory):
        language = filename[-2:]
        abbreviations[language] = {"regular": set(), "numeric": set(), "no_boundary": set()}
        with open(os.path.join(directory, filename)) as fh:
            for line in fh:
                line = line.strip()
                if not line.startswith("#"):
                    if line.endswith("#NUMERIC_ONLY#"):
                        abbreviations[language]["numeric"].add(line[0:len(line) - 14].strip().lower())
                    elif line.endswith("#NO_BOUNDARY#"):
                        abbreviations[language]["no_boundary"].add(line[0:len(line) - 13].strip().lower())
                    else:
                        abbreviations[language]["regular"].add(line.lower())
        assert len(abbreviations[language]["regular"] & abbreviations[language]["numeric"]) == 0
        assert len(abbreviations[language]["regular"] & abbreviations[language]["no_boundary"]) == 0
        assert len(abbreviations[language]["numeric"] & abbreviations[language]["no_boundary"]) == 0
    return abbreviations


def load_captioning_specials(captioning_file):
    """Read in captioning_specials file"""
    captioning_specials = {}
    if captioning_file is None:
        return captioning_specials
    for line in captioning_file:
        parent_dict = captioning_specials
        split = line.strip().split("\t")
        for s in split:
            if s not in parent_dict:
                s = s.strip()
                parent_dict[s] = {}
                parent_dict = parent_dict[s]
    return captioning_specials


def is_abbreviation(word, next_word, abbreviations, language):
    """Check if word is an abbreviation in language."""
    if language not in abbreviations:
        language = "en"
    if word.lower() in abbreviations[language]["regular"]:
        return True
    if word.lower() in abbreviations[language]["numeric"] and re.search("^[+-]?\d+", next_word):
        return True
    if re.search(r"\.\S+$", word):
        return True
    return False


def check_normal_case_sentences(sentences, abbreviations, language):
    """Check if sentence candidates in normal case should be split."""
    for sentence in sentences:
        # if more than one 25% of the characters in a sentence are
        # lower case, we assume it is in normal case
        sentence_wo_tags = re.sub(r"</?ccline[^>]*>", "", sentence)
        lc_chars = sum([1 for c in sentence_wo_tags if c.islower()])
        if float(lc_chars) / len(sentence_wo_tags) >= 0.25:
            new_sentences = []
            # tags as single tokens
            sentence = re.sub(r"(<ccline) (start=\S+) (end=[^>]+) (/>)", r"\1_\2_\3_\4", sentence)
            words = re.split("\s+", sentence)
            for i, word in enumerate(words):
                word = re.sub(r"(<ccline)_(start=[^_]+)_(end=[^>_]+)_(/>)", r"\1 \2 \3 \4", word)
                if i == 0:
                    new_sentences.append([word])
                    continue
                current_word = re.sub(r"</?ccline[^>]*>", "", word)
                previous_word = re.sub(r"</?ccline[^>]*>", "", words[i - 1])
                word_starts_uc = current_word[0].isupper()
                # if word starts with a capital letter, it might be
                # the beginning of a new sentence
                if word_starts_uc:
                    previous_word_ends_with_period_only = previous_word.endswith(".") and not previous_word.endswith(
                        "...")
                    previous_word_ends_with_period_and_more = re.search(r"(?<!\.\.)\.[])}'\"“”‘’]+$", previous_word)
                    previous_word_ends_with_other_punct = re.search(r"[?!][])}'\"“”‘’]*$", previous_word)
                    if previous_word_ends_with_period_only:
                        previous_word_wo_punc = re.sub(r"\.[])}'\"“”‘’]*$", "", previous_word)
                        previous_word_is_abbreviation = is_abbreviation(previous_word_wo_punc, word, abbreviations,
                                                                        language)
                        if previous_word_is_abbreviation:
                            new_sentences[-1].append(word)
                        else:
                            new_sentences.append([word])
                    elif previous_word_ends_with_period_and_more:
                        new_sentences.append([word])
                    elif previous_word_ends_with_other_punct:
                        new_sentences.append([word])
                    else:
                        new_sentences[-1].append(word)
                # word does not start with a capital letter, therefore
                # it cannot be the beginning of a new sentence
                else:
                    new_sentences[-1].append(word)
            for new_sentence in new_sentences:
                yield " ".join(new_sentence)
        # less than 25% of characters are lower case, so we do not
        # need any special postprocessing
        else:
            yield sentence


def _check_end_of_lines(text, timestamps, line_lengths, max_line_length, boundaries, abbreviations, language):
    """Check if punctuation at the end of a line marks a sentence
    boundary."""
    sentences = []
    for line, timestamp in zip(text, timestamps):
        line = line.lstrip()
        escapedline = xmlescape(line);
        tagged_line = '<ccline start="%s" end="%s" />%s' % (timestamp[0], timestamp[1], escapedline)
        #        closing_tag = "</ccline>"
        closing_tag = ""
        # skip empty lines
        if line == "":
            continue
        if len(sentences) == 0:
            sentences.append([tagged_line])
            continue
        # not the first line, so add closing tag
        previous_line = re.sub(r"</?ccline[^>]*>", "", sentences[-1][-1])
        previous_line = xmlunescape(previous_line);
        sentences[-1][-1] += closing_tag
        # if the previous line ends with "♪", we have a new sentence
        previous_line_ends_with_sound_mark = previous_line.endswith("♪")
        if previous_line_ends_with_sound_mark:
            sentences.append([tagged_line])
            continue
        # if the line begins with a boundary, we have a new sentence
        first_word = re.split("\s+", line)[0]
        if first_word in boundaries:
            sentences.append([tagged_line])
            continue
        # first_word_starts_lc = first_word[0].islower()
        previous_line_ends_with_period_only = previous_line.endswith(".") and not previous_line.endswith("...")
        # period (not preceded by two periods) followed by a
        # combination of other punctuation
        previous_line_ends_with_period_and_more = re.search(r"(?<!\.\.)\.[])}'\"“”‘’]+$", previous_line)
        previous_line_ends_with_other_punct = re.search(r"[?!][])}'\"“”‘’]*$", previous_line)
        if previous_line_ends_with_period_only:
            first_word_would_have_fit = len(previous_line) + len(first_word) + 1 <= max_line_length
            previous_words = re.split("\s+", previous_line)
            previous_last_word = previous_words[len(previous_words) - 1]
            previous_last_word = re.sub(r"\.[])}'\"“”‘’]*$", "", previous_last_word)
            if previous_last_word.lower() in abbreviations[language]["no_boundary"]:
                sentences[-1].append(tagged_line)
            elif first_word_would_have_fit:
                sentences.append([tagged_line])
            elif is_abbreviation(previous_last_word, first_word, abbreviations, language):
                sentences[-1].append(tagged_line)
            else:
                sentences.append([tagged_line])
        elif previous_line_ends_with_period_and_more:
            sentences.append([tagged_line])
        elif previous_line_ends_with_other_punct:
            sentences.append([tagged_line])
        else:
            sentences[-1].append(tagged_line)
    # closing tag for last line
    if len(sentences) > 0:
        sentences[-1][-1] += closing_tag
    sentences = [" ".join(s) for s in sentences]
    # lines in normal case can contain sentence boundaries, so we have
    # to check these sentence candidates
    sentences = list(check_normal_case_sentences(sentences, abbreviations, language))
    return sentences


def get_fuzzy_key(key, dictionary, min_accuracy=95):
    """Gets the most matching key in the dictionary if its accuracy is at least min_accuracy else None"""
    possible_keys = fuzzy.extract(key, dictionary.keys(), limit=1)
    if len(possible_keys) == 0:
        return None
    fuzzy_key, accuracy = possible_keys[0]
    if accuracy >= min_accuracy:
        return fuzzy_key
    return None


def extract_captioning(text, specials):
    """Deletes captioning lines and adds their content to a returned captioning tag"""
    pattern = re.compile(r"((.+)?(Caption(?:ing|ed))((?:(?!by).)*(by)?(.+)?))", re.IGNORECASE)
    pattern_by = re.compile(r"by", re.IGNORECASE)
    pattern_web_address = re.compile(r"[\t ]*(?:\w+([.@])){2,}\w+")
    pattern_and = re.compile(r"and.*", re.IGNORECASE)

    captioning_content = []
    line_numbers_with_caption = []
    left_special_lines = 0
    for i, line in enumerate(text):
        if left_special_lines == 0:
            left_special_lines = number_of_following_special_lines(i, left_special_lines, line, specials, text)
        # check if the line and the following ones match any captioning_special
        # if the line belongs to the found captioning_special lines
        if left_special_lines > 0:
            captioning_content.append(line.strip())
            line_numbers_with_caption.append(i)
            left_special_lines -= 1
            continue
        # use the regex patterns to determine if a captioning is found
        match = re.match(pattern, line)
        if match is None:
            continue
        contains_a_by = match.group(5) is not None
        ends_with_by = contains_a_by and (match.group(6) is None or match.group(6).strip() == "")
        has_next_line = len(text) > i + 1
        next_line_starts_with_by = has_next_line and re.match(pattern_by, text[i+1]) is not None
        next_line_starts_with_and = has_next_line and re.match(pattern_and, text[i+1]) is not None
        if not contains_a_by and not next_line_starts_with_by:
            continue    # is the word captioning or captioned within the normal story
        captioning_content.append(line.strip())
        line_numbers_with_caption.append(i)
        used_lines = 1
        if ends_with_by or next_line_starts_with_by or (contains_a_by and next_line_starts_with_and):
            captioning_content.append(text[i+used_lines].strip())   # next line is still captioning because of by or and
            line_numbers_with_caption.append(i+used_lines)
            used_lines += 1
        if len(text) > i + used_lines and re.match(pattern_web_address, text[i+used_lines]):
            captioning_content.append(text[i+used_lines].strip())  # add web address
            line_numbers_with_caption.append(i+used_lines)

    for i in reversed(line_numbers_with_caption):  # delete the captioning lines from text
        del text[i]
    # create the captioning tag
    captioning_tag = '<meta type="caption_credits" value="{}"/>'.format(" ".join(captioning_content).strip(" []\t")) \
        if len(captioning_content) > 0 else None
    return text, captioning_tag


def number_of_following_special_lines(i, left_special_lines, line, specials, text):
    fuzzy_key_line = get_fuzzy_key(line.strip(), specials)
    if fuzzy_key_line is not None:
        special_parent = specials
        for j, l in enumerate(text[i:]):
            fuzzy_key_l = get_fuzzy_key(l.strip(), special_parent)
            if fuzzy_key_l is None:
                break
            if len(special_parent[fuzzy_key_l]) == 0:
                left_special_lines = j + 1
            special_parent = special_parent[fuzzy_key_l]
    return left_special_lines


def split_into_sentences(text, timestamps, abbreviations, captioning_specials, language="en"):
    """Split text into sentences, considering language."""
    # one line can have a maximum of 32 characters
    max_line_length = 32
    # >> marks a speaker change
    # >>> marks a story boundary
    # ♪ indicates music
    boundaries = set([">>", ">>>", "♪"])
    # whitespace at the end of lines does not count towards line
    # lengths
    text = [l.rstrip() for l in text]
    line_lengths = [len(l) for l in text]
    text, captioning_tag = extract_captioning(text, captioning_specials)

    # punctuation at the end of a line
    sentences = _check_end_of_lines(text, timestamps, line_lengths, max_line_length, boundaries, abbreviations,
                                    language)
    # punctuation in the middle of a line
    # ...
    if captioning_tag is not None:
        sentences.insert(0, captioning_tag)
    return sentences


def parse_capture_file(file_object, abbreviations, captioning_specials):
    """Parse the capture file, i.e. identify meta data, time stamps,
    etc."""
    timestamp_re = re.compile(r"^\d{14}\.\d{3}$")
    # changed one_field_metadata and two_field_metadata since that is not a sensible distinction (there may be one or two field in VID, for instance)
    file_level_metadata = set(
        ["TOP", "COL", "UID", "PID", "ACQ", "DUR", "VID", "TTL", "URL", "TTS", "SRC", "CMT", "LAN", "TTP", "HED", "OBT",
         "LBT", "END"])
    text = []
    timestamps = []
    sentences = []
    # Pre-Initialization
    video_resolution = "N/A"
    collection = "Communication Studies Archive, UCLA"
    original_broadcast_date = "N/A"
    original_broadcast_time = "N/A"
    original_broadcast_timezone = "N/A"
    local_broadcast_date = "N/A"
    local_broadcast_time = "N/A"
    local_broadcast_timezone = "N/A"
    opened_segment = None
    segment_type = "story_start"
    for line in file_object:
        line = line.strip()
        fields = line.split("|")
        if timestamp_re.search(fields[0]):
            if fields[2].startswith("SEG"):
                new_sentences = split_into_sentences(text, timestamps, abbreviations, captioning_specials)
                add_segment_tag(opened_segment, new_sentences)
                sentences.extend(new_sentences)
                text = []
                timestamps = []
                if len(fields) > 3:
                    segment_type = fields[3].split("=")[-1]
            elif fields[2] == "CC1" or fields[2] == "CCO" or fields[2] == "TR0" or fields[
                2] == "TR1":  # Verify this is doing the right thing...
                text.extend(fields[3:])
                timestamps.append(fields[0:2])
            opened_segment = '\n<segment type="{}">\n'.format(segment_type.lower().replace(" ", "_"))
        elif fields[0] in file_level_metadata:
            if fields[0] == "TOP":
                timestamp = fields[1]
                topfields = fields[2].split("_")
                thedate = topfields.pop(0)
                datefields = thedate.split("-")
                thetime = topfields.pop(0)
                d = date(int(datefields[0]), int(datefields[1]), int(datefields[2]))
                t = time(int(fields[1][8:10]), int(fields[1][10:12]), int(fields[1][12:14]))
                filestartdatetime = datetime.combine(d, t)
                country = topfields.pop(0)
                channel = topfields.pop(0)
                channel = re.sub(r"[^A-Za-z0-9]", "_", channel)
                channel = re.sub(r"^([0-9])", r"_\1", channel)
                title = xmlescape(" ".join(topfields))
            if fields[0] == "COL":
                collection = xmlescape(fields[1])
            if fields[0] == "UID":
                uid = fields[1].replace("-", "_")
            if fields[0] == "PID":
                program_id = xmlescape(fields[1])
            if fields[0] == "ACQ":
                pass  # NO SUCH THING??? -> Would like to know the format. acquisition_time = fields[1]; But what if it is date and time?
            if fields[0] == "DUR":
                duration = xmlescape(fields[1])
            if fields[0] == "VID":
                video_resolution = xmlescape(fields[1])
                try:
                    video_resolution_original = xmlescape(fields[2])
                except IndexError:
                    pass
            if fields[0] == "TTL":
                event_title = xmlescape(fields[1])
            if fields[0] == "URL":
                url = xmlescape(fields[1])
            if fields[0] == "TTS":
                transcript_type = xmlescape(fields[1])
            if fields[0] == "SRC":
                recording_location = xmlescape(fields[1])
            if fields[0] == "CMT":
                if fields[1] != "":
                    scheduler_comment = xmlescape(fields[1])
            if fields[0] == "LAN":
                language = xmlescape(fields[1])
            if fields[0] == "TTP":
                teletext_page = xmlescape(fields[1])
            if fields[0] == "HED":
                theheader = xmlescape(fields[1])
            if fields[0] == "OBT":
                try:
                    original_broadcast_date, original_broadcast_time, original_broadcast_timezone = fields[2].split(" ")
                except ValueError:
                    pass
                except IndexError:
                    try:
                        original_broadcast_date, original_broadcast_time, original_broadcast_timezone = fields[1].split(
                            " ")
                    except ValueError:
                        pass
                else:
                    original_broadcast_estimated = "true"
            if fields[0] == "LBT":
                try:
                    local_broadcast_date, local_broadcast_time, local_broadcast_timezone = fields[1].split(" ")
                except ValueError:
                    pass
            if fields[0] == "END":
                new_sentences = split_into_sentences(text, timestamps, abbreviations, captioning_specials)
                add_segment_tag(opened_segment, new_sentences)
                sentences.extend(new_sentences)
                text = []
    sys.stdout.write(
        "<text id=\"t__%s\" collection=\"%s\" file=\"%s\" date=\"%s\" year=\"%s\" month=\"%s\" day=\"%s\" time=\"%s\" duration=\"%s\" country=\"%s\" channel=\"%s\" title=\"%s\" video_resolution=\"%s\"" % (
        uid, collection, file_object.name, thedate, datefields[0], datefields[1], datefields[2], thetime, duration,
        country, channel, title, video_resolution))
    try:
        video_resolution_original
    except NameError:
        pass
    else:
        sys.stdout.write(" video_resolution_original=\"%s\"" % (video_resolution_original))

    try:
        scheduler_comment
    except NameError:
        pass
    else:
        sys.stdout.write(" scheduler_comment=\"%s\"" % (scheduler_comment))

    try:
        language
    except NameError:
        pass
    else:
        sys.stdout.write(" language=\"%s\"" % (language))

    try:
        url
    except NameError:
        pass
    else:
        sys.stdout.write(" url=\"%s\"" % (url))

    try:
        recording_location
    except NameError:
        pass
    else:
        sys.stdout.write(" recording_location=\"%s\"" % (recording_location))

    try:
        program_id
    except NameError:
        pass
    else:
        sys.stdout.write(" program_id=\"%s\"" % (program_id))

    try:
        transcript_type
    except NameError:
        pass
    else:
        sys.stdout.write(" transcript_type=\"%s\"" % (transcript_type))

    try:
        teletext_page
    except NameError:
        pass
    else:
        sys.stdout.write(" teletext_page=\"%s\"" % (teletext_page))

    try:
        theheader
    except NameError:
        pass
    else:
        sys.stdout.write(" header=\"%s\"" % (theheader))

    try:
        original_broadcast_date
    except NameError:
        pass
    else:
        sys.stdout.write(
            " original_broadcast_date=\"%s\" original_broadcast_time=\"%s\" original_broadcast_timezone=\"%s\"" % (
            original_broadcast_date, original_broadcast_time, original_broadcast_timezone))

    try:
        original_broadcast_estimated
    except NameError:
        pass
    else:
        sys.stdout.write(" original_broadcast_estimated=\"%s\"" % (original_broadcast_estimated))

    try:
        local_broadcast_date
    except NameError:
        pass
    else:
        sys.stdout.write(" local_broadcast_date=\"%s\" local_broadcast_time=\"%s\" local_broadcast_timezone=\"%s\"" % (
        local_broadcast_date, local_broadcast_time, local_broadcast_timezone))

    sys.stdout.write(">")
    """    storyboundary = re.compile(r'(?<=>)(\s*>>>\s*)+')
    storyboundaryeol = re.compile(r'(?<!("|\'|/))(?:\s*>>>\s*)+</ccline')
    turnboundary = re.compile(r'(?<=>)(\s*>>\s*)+')
    turnboundaryeol = re.compile(r'(?<!("|\'|/))(?:\s*>>\s*)+</ccline')
    storyboundaryinline = re.compile(r'(?<!>)\s*>>>\s+')
    turnboundaryinline = re.compile(r'(?<!("|\'|/))\s*>>\s+')
    turnboundaryonechevron = re.compile(r'(?<!>)(?:>\s*>\s*)+')
    colonidentification = re.compile(r'(?<!>)>\s*([A-Za-z]+):\s*')
    for sentence in sentences:
        sentence = re.sub(r'&', '&amp;', sentence);
        storyboundarymatch = storyboundary.search(sentence)
        if storyboundarymatch:
            sentence = storyboundary.sub("\n<storyboundary />", sentence)
#            print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
#            print(sentence);
#            print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
        storyboundaryeolmatch = storyboundaryeol.search(sentence)
        if storyboundaryeolmatch:
            sentence = storyboundaryeol.sub("\n<storyboundary /></ccline", sentence)
        turnboundarymatch = turnboundary.search(sentence)
        if turnboundarymatch:
            sentence = turnboundary.sub("\n<turnboundary />", sentence)
        turnboundaryeolmatch = turnboundaryeol.search(sentence)
        if turnboundaryeolmatch:
            sentence = turnboundaryeol.sub("\n<turnboundary /></ccline", sentence)
        storyboundaryinlinematch = storyboundaryinline.search(sentence)
        if storyboundaryinlinematch:
            sentence = storyboundaryinline.sub("\n<storyboundary />", sentence)
        turnboundaryinlinematch = turnboundaryinline.search(sentence)
        if turnboundaryinlinematch:
            sentence = turnboundaryinline.sub("\n<turnboundary />", sentence)
        turnboundaryonechevronmatch = turnboundaryonechevron.search(sentence)
        if turnboundaryonechevronmatch:
            sentence = turnboundaryonechevron.sub(">\n<turnboundary />", sentence)
        colonidentifcation.sub(colonfunction)
#        colonidentificationmatchiterator = colonidentification.finditer(sentence)
#        for colonidentificationmatch in colonidentifcationiterator:
            print("HALLO" + colonidentificationmatch.group(1))
            if words_with_colons_dictionary[colonidentificationmatch.group(1)][0] == "s":
                # only the item itself
                if len(words_with_colons_dictionary[colonidentificationmatch.group(1)]) > 1:
#                    print("<meta type=\"speakeridentification\" value=\"" + words_with_colons_dictionary[colonidentificationmatch.group(1)][1] + "\" original_value=\"" + colonidentificationmatch.group(1) + "\" />")
                    insertthis = "<meta type=\"speakeridentification\" value=\"" + words_with_colons_dictionary[colonidentificationmatch.group(1)][1] + "\" original_value=\"" + colonidentificationmatch.group(1) + "\" />"
                else:
#                    print("<meta type=\"speakeridentification\" value=\"" + colonidentificationmatch.group(1) + "\" />")
                    insertthis = "<meta type=\"speakeridentification\" value=\"" + colonidentificationmatch.group(1) + "\" />"
                sentence = colonidentification.sub(">" + insertthis, sentence)
            elif words_with_colons_dictionary[colonidentificationmatch.group(1)][0] == "m":
                print("BELLO")
                # whole line
                if len(words_with_colons_dictionary[colonidentificationmatch.group(1)]) > 1:
                    print("<meta type=\"music\" value=\"" + words_with_colons_dictionary[colonidentificationmatch.group(1)][1] + "\" original_value=\"" + colonidentificationmatch.group(1) + "\" />")
                else:
                    print("<meta type=\"music\" value=\"" + colonidentificationmatch.group(1) + "\" />")
                sentence = colonidentification.sub(">", sentence)
            elif words_with_colons_dictionary[colonidentificationmatch.group(1)][0] == "t":
                # whole line
                pass
            elif words_with_colons_dictionary[colonidentificationmatch.group(1)][0] == "a":
                # whole line
                pass
            else:
                # This makes sure I did not forget any annotations.
#                print(colonidentificationmatch.group(1) + " --- " + words_with_colons_dictionary[colonidentificationmatch.group(1)][0]);
                assert words_with_colons_dictionary[colonidentificationmatch.group(1)][0] == "i"
#                print "<
        print(sentence)"""
    print("\n<sentenceboundary />".join(sentences))
    print("</text>")


def add_segment_tag(opened_segment, new_sentences):
    if len(new_sentences) == 0:
        new_sentences = [""]
    new_sentences[0] = opened_segment + new_sentences[0]
    new_sentences[-1] += '\n</segment>'
    return new_sentences


def main():
    """Main function"""
    args = command_line_arguments()
    #    bracket_dictionary = load_bracket_dictionary()
    #    words_with_colons_dictionary = load_words_with_colons_dictionary()
    abbreviations = load_abbreviations(args.a)
    captioning_specials = load_captioning_specials(args.c)
    sys.stderr.write("Processing " + args.FILE.name + "\n")
    parse_capture_file(args.FILE, abbreviations, captioning_specials)


if __name__ == "__main__":
    main()
