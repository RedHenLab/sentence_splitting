# sentence_splitting


This currently only works for the English-language files.
Usage:
```bash
python3 sentence_splitting.py -a /path/to/nonbreaking_prefixes/ inputfile.txt | perl filter_metainfo_from_cclines.pl path/to/dictionaries | perl join_lines.pl > outputfile.xml
```

The output is a well-formed XML file that contains exactly one sentence per line. XML tags relevant to the sentence are not guaranteed to be on the same line as the sentence.

The output can then be processed with Stanford CoreNLP using the following commands (for version 3.7.0).

Dependency Parser:
```bash
java -XX:+UseNUMA -Xmx3g -cp "/path/to/stanford-corenlp-full-2016-10-31/*" edu.stanford.nlp.pipeline.StanfordCoreNLP -pos.model edu/stanford/nlp/models/pos-tagger/english-caseless-left3words-distsim.tagger -parse.model edu/stanford/nlp/models/srparser/englishSR.beam.ser.gz -annotators tokenize,cleanxml,ssplit,pos,truecase,lemma,ner,depparse -parse.maxlen 100 -ssplit.eolonly true -truecase.overwriteText true -outputFormat json -file outputfile.xml
```
Full pipeline with Shift-Reduce parser with beam search (less robust!!):
```bash
java -XX:+UseNUMA -Xmx5g -XX:MaxMetaspaceSize=1g -Xss2048k -cp "/path/to/stanford-corenlp-full-2016-10-31/*" edu.stanford.nlp.pipeline.StanfordCoreNLP -pos.model edu/stanford/nlp/models/pos-tagger/english-caseless-left3words-distsim.tagger -parse.model edu/stanford/nlp/models/srparser/englishSR.beam.ser.gz -annotators tokenize,cleanxml,ssplit,pos,truecase,lemma,ner,parse,dcoref,relation,natlog,quote,sentiment -parse.maxlen 100 -ssplit.eolonly true -coref.algorithm neural -truecase.overwriteText true -outputFormat json -file outputfile.xml
```

Given the long setup time, it may make sense to use -filelist instead of -file to process multiple files at once.
