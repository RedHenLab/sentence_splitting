# sentence_splitting


This currently only works for the English-language files.
Usage:
```bash
python3 sentence_splitting.py -a /path/to/nonbreaking_prefixes/ inputfile.txt | perl filter_metainfo_from_cclines.pl > outputfile.txt
```
