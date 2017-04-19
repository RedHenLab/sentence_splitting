#!/usr/bin/perl

# This files takes as input the output from sentence_splitting.py


use strict;
use Data::Dumper;
use utf8;
use open qw(:std :utf8); # This also works for the Diamond Operator
binmode STDOUT, ':utf8';

# Path to dictionaries
my $dictpath = $ARGV[0] or die "Please specifiy the path to the dictionaries\n";

# LOADING RESOURCES

# Set the abbreviations in the dictionaries
my %fullvalues = (
	"s" => "speakeridentification", # (John, woman, captain)
	"a" => "audio_description", # including silence
	"f" => "foreign_language", # not English
	"l" => "lyrics", # music with words
	"m" => "music", # music without words (can have words, but the lyrics are not in the captions)
	"o" => "orientation", # orienting information -- meta-information about the program (END CLIP)
	"p" => "paralinguistic_signal", # applause, laugh, sigh, hiss
	"q" => "quality_of_expression", # unenthusiastic, sheepishly, proudly, nervously
	"t" => "on-screen_text_repeated_in_captions" # (seems to occur only on WWW_Russia so far)
#	"u" => "undetermined", # Should this be here, actually?
#	"n" => "not in brackets" # (mistaken entry)
#	"i" => "ignore", # the term is spoken
);


# Word with colon
my %coldict;
open(my $cfh, "<:encoding(UTF-8)", $dictpath."/words_with_colons_dictionary.txt") or die "Can't open < words_with_colons_dictionary.txt: $!";
while (<$cfh>) {
	chomp;
	my @fields = split "\t";
	my $index = shift(@fields);
	$coldict{$index} = [@fields];
}
close($cfh);
#print Dumper(%coldict);
#die;

# Bracketed expressions
my %brackdict;
my @filenames = ("round_brackets_dictionary.txt", "square_brackets_dictionary.txt");
foreach my $filename (@filenames) {
	open(my $bfh, "<:encoding(UTF-8)", $dictpath."/".$filename) or die "Can't open < $filename: $!";
	while (<$bfh>) {
		chomp;
		my @fields = split "\t";
		my $index = shift(@fields);
		$brackdict{$index} = [@fields];
	}
	close($bfh);
}
#print Dumper(%brackdict);
#die;

# SETTINGS for XML checking: We need pseudo-XML for CWB but actual XML to verify the file. So we can set the opening and closing tags here and can decide which we want to check by making them the open/close tags and the other the self-closing ones.
# The files should be well-formed and validate with both settings.

# SETTING 1 - does not conform to XML standard but is what we need for CQP; however, Stanford CoreNLP does not like this.
#my $storystart = "<story>";
#my $storyend = "</story>";
#my $turnstart = "<turn>";
#my $turnend = "</turn>";

# SETTING 2 - conforms to XML standard
my $storystart = "<story_start />";
my $storyend = "<story_end />";
my $turnstart = "<turn>";
my $turnend = "</turn>";

# SETTING 3 - conforms to XML standard
#my $storystart = "<story>";
#my $storyend = "</story>";
#my $turnstart = "<turn_start />";
#my $turnend = "<turn_end />";


my $storyopen = 0;
my $turnopen = 0;

print '<?xml version="1.0" encoding="UTF-8"?>',"\n";

# MAIN LOOP

while (my $x = <STDIN>) {
	chomp $x;
	$x =~ s/\x00//g;
	$x =~ s/\x02//g;
	$x =~ s/\x03//g;
	$x =~ s/\x06//g;
	$x =~ s/\x0F//g;
	$x =~ s/\x1B//g;
	$x =~ s/\x19/&apos;/g;
	print "BELLO INLINE: $x\n";

	# First let's get rid of the first and last line with the text-tags.
	if ($x =~ /^<\/?text/) {
		if ($x =~ /<\/text>/) {
			if ($turnopen == 1) {
				$x =~ s/<\/text>/$turnend<\/text>/;
				$turnopen = 0;
			}
			if ($storyopen == 1) {
				$x =~ s/<\/text>/$storyend<\/text>/;
				$storyopen = 0;
			}
		}
		print $x,"\n";
		next;
	}
	# Not yet quite sure why the following line is there. Took it over from the Python version, so I must have seen the need somewhere.
#	$x =~ s/&/&amp;/g;
	
	my @matches = ();



	# Story boundary
	if ($storyopen == 1) {
		# Close open tag and open a new one for every occurrence
		$x =~ s/(?<=>)(\s*&gt;&gt;&gt;\s*)+/$storyend$storystart/g;
	}
	else {
		# Open a new tag and then close the open tag and open a new one for ever further occurrence
		if ($x =~ s/(?<=>)(\s*&gt;&gt;&gt;\s*)+/$storystart/) {
			$x =~ s/(?<=>)(\s*&gt;&gt;&gt;\s*)+/$storyend$storystart/g;
			$storyopen = 1;
		}
	}

	# Story boundary inline
	if ($storyopen == 1) {
		# Close open tag and open a new one for every occurrence
		$x =~ s/(?<!>)\s*&gt;&gt;&gt;\s+/\n$storyend$storystart/g;
	}
	else {
		# Open a new tag and then close the open tag and open a new one for ever further occurrence
		if ($x =~ s/(?<!>)\s*&gt;&gt;&gt;\s+/\n$storystart/) {
			$x =~ s/(?<!>)\s*&gt;&gt;&gt;\s+/\n$storyend$storystart/g;
			$storyopen = 1;
		}
	}

	# Story boundary EOL
	if ($storyopen == 1) {
		# Close open tag and open a new one for every occurrence
		$x =~ s/(?<!("|'|\/))(?:\s*&gt;&gt;&gt;\s*)+<ccline/\n$storyend$storystart<ccline/g;
	}
	else {
		# Open a new tag and then close the open tag and open a new one for ever further occurrence
		if ($x =~ s/(?<!("|'|\/))(?:\s*&gt;&gt;&gt;\s*)+<ccline/\n$storystart<ccline/) {
			$x =~ s/(?<!("|'|\/))(?:\s*&gt;&gt;&gt;\s*)+<ccline/\n$storyend$storystart<ccline/g;
			$storyopen = 1;
		}
	}
	# Turn boundary
	if ($turnopen == 1) {
		# Close open tag and open a new one for every occurrence
		$x =~ s/(?<=>)(\s*&gt;&gt;\s*)+/$turnend$turnstart/g;
		print "BELLO ", __LINE__, " ", $turnopen,"\n";
	}
	else {
		# Open a new tag and then close the open tag and open a new one for ever further occurrence
		if ($x =~ s/(?<=>)(\s*&gt;&gt;\s*)+/$turnstart/) {
			$x =~ s/(?<=>)(\s*&gt;&gt;\s*)+/$turnend$turnstart/g;
			$turnopen = 1;
			print "BELLO ", __LINE__, " ", $turnopen,"\n";
		}
	}

	# Turn boundary inline
	if ($turnopen == 1) {
		$x =~ s/(?<!(&quot;|&apos;))\s*&gt;&gt;\s+/\n$turnend$turnstart/g;
		$x =~ s/(?<!(\/))\s*&gt;&gt;\s+/\n$turnend$turnstart/g;
	}
	else {
		my $firstmatch1;
		my $firstmatch2;
		my $dotheymatch = 0;
		if ($x =~ /(?<!(&quot;|&apos;))\s*(&gt;&gt;)\s+/) {
			$dotheymatch = 1;
			$firstmatch1 = $-[2];
		}
		if ($x =~ /(?<!(\/))\s*(&gt;&gt;)\s+/) {
			$dotheymatch = 1;
			$firstmatch2 = $-[2];
		}
print "BELLO ", __LINE__, " Firstmatch1 $firstmatch1 Firstmatch2 $firstmatch2\n";
		if (($dotheymatch == 1) && ($firstmatch1 <= $firstmatch2)) { # equals should not occur, but we'll better treat this case
print "BELLO ", __LINE__, " ", $turnopen,"\n";
			# Open a new tag and then close the open tag and open a new one for ever further occurrence
			$x =~ s/(?<!(&quot;|&apos;))\s*&gt;&gt;\s+/\n$turnstart/;
			$x =~ s/(?<!(&quot;|&apos;))\s*&gt;&gt;\s+/\n$turnend$turnstart/g;
			$x =~ s/(?<!(\/))\s*&gt;&gt;\s+/\n$turnend$turnstart/g;
			$turnopen = 1;
		}
		elsif (($dotheymatch == 1) && ($firstmatch1 > $firstmatch2)) {
print "BELLO ", __LINE__, " ", $turnopen,"\n";
			# Open a new tag and then close the open tag and open a new one for ever further occurrence
			$x =~ s/(?<!(\/))\s*&gt;&gt;\s+/\n$turnstart/;
			$x =~ s/(?<!(&quot;|&apos;))\s*&gt;&gt;\s+/\n$turnend$turnstart/g;
			$x =~ s/(?<!(\/))\s*&gt;&gt;\s+/\n$turnend$turnstart/g;
			$turnopen = 1;
		}
	}

	# Turn boundary EOL
	if ($turnopen == 1) {
print "BELLO ", __LINE__, " ", $turnopen,"\n";
		$x =~ s/(?<!(&quot;|&apos;))(?:\s*&gt;&gt;\s*)+<ccline/\n$turnend$turnstart<ccline/g;
		$x =~ s/(?<!(\/))(?:\s*&gt;&gt;\s*)+<ccline/\n$turnend$turnstart<ccline/g;
	}
	else {
		my $firstmatch1;
		my $firstmatch2;
		my $dotheymatch = 0;
		if ($x =~ /(?<!(&quot;|&apos;))(?:\s*(&gt;&gt;)\s*)+<ccline/) {
			$dotheymatch = 1;
			$firstmatch1 = $-[2];
		}
		if ($x =~ /(?<!(\/))(?:\s*(&gt;&gt;)\s*)+<ccline/) {
			$dotheymatch = 1;
			$firstmatch2 = $-[2];
		}
print "BELLO ", __LINE__, " Firstmatch1 $firstmatch1 Firstmatch2 $firstmatch2\n";
		if (($dotheymatch == 1) && ($firstmatch1 <= $firstmatch2)) { # equals should not occur, but we'll better treat this case
			# Open a new tag and then close the open tag and open a new one for ever further occurrence
print "BELLO ", __LINE__, " ", $turnopen,"\n";
			$x =~ s/(?<!(&quot;|&apos;))(?:\s*&gt;&gt;\s*)+<ccline/\n$turnstart<ccline/;
			$x =~ s/(?<!(&quot;|&apos;))(?:\s*&gt;&gt;\s*)+<ccline/\n$turnend$turnstart<ccline/g;
			$x =~ s/(?<!(\/))(?:\s*&gt;&gt;\s*)+<ccline/\n$turnend$turnstart<ccline/g;
			$turnopen = 1;
		}
		elsif (($dotheymatch == 1) && ($firstmatch1 > $firstmatch2)) {
print "BELLO ", __LINE__, " ", $turnopen,"\n";
			# Open a new tag and then close the open tag and open a new one for ever further occurrence
			$x =~ s/(?<!(\/))(?:\s*&gt;&gt;\s*)+<ccline/\n$turnstart<ccline/;
			$x =~ s/(?<!(&quot;|&apos;))(?:\s*&gt;&gt;\s*)+<ccline/\n$turnend$turnstart<ccline/g;
			$x =~ s/(?<!(\/))(?:\s*&gt;&gt;\s*)+<ccline/\n$turnend$turnstart<ccline/g;
			$turnopen = 1;
		}
	}

	# Turn boundary one chevron only
	if ($turnopen == 1) {
print "BELLO ", __LINE__, " ", $turnopen,"\n";
		$x =~ s/(?<!>)(?:>\s*&gt;\s*)+/>\n$turnend$turnstart/g;
	}
	else {
print "BELLO ", __LINE__, " ", $turnopen,"\n";
		if ($x =~ s/(?<!>)(?:>\s*&gt;\s*)+/>\n$turnstart/) {
print "BELLO ", __LINE__, " ", $turnopen,"\n";
			$x =~ s/(?<!>)(?:>\s*&gt;\s*)+/>\n$turnend$turnstart/g;
			$turnopen = 1;
		}
print "BELLO ", __LINE__, " ", $turnopen,"\n";
	}
	# Musical Notes:
	$x =~ s/(♪+)/<musicalnotes value="$1" \/>/g;


	my $linewithoutcctags = $x;
	$linewithoutcctags =~ s/<\/?ccline[^<>]+>//g;
	$linewithoutcctags =~ s/^\s*//;
	$linewithoutcctags =~ s/\s*$//;
#	print "XXXXXXXXX", $linewithoutcctags, "\n";
	if (($linewithoutcctags =~ /$storystart/) && ($linewithoutcctags !~ /^$storystart/)) {
		$x =~ s/$storystart/\n$storystart/;
	}
	if (($linewithoutcctags =~ /$turnstart/) && ($linewithoutcctags !~ /^$turnstart/)) {
print "BELLO ", __LINE__, " ", $turnopen,"\n";
		$x =~ s/$turnstart/\n$turnstart/;
	}

	# words with colons
	if (@matches = $x =~ /(?<!>)>\s*([A-Za-z]+):\s*/g) {
		foreach my $match (@matches) {
			next unless $coldict{$match};
			if ($coldict{$match}[0] eq "s") { # only the item itself
				my $closingturn = "";
print "BELLO ", __LINE__, " ", $turnopen,"\n";
				if ($turnopen == 1) {
					$closingturn = $turnend;
				}
				if (@{$coldict{$match}} > 1) {
					my $value = $coldict{$match}[1];
					$x =~ s/(?<!>)>\s*([A-Za-z]+):\s*/>$closingturn<meta type="speakeridentification" originalvalue="$1" value="$value" \/>$turnstart/;
				}
				else {
					$x =~ s/(?<!>)>\s*([A-Za-z]+):\s*/>$closingturn<meta type="speakeridentification" value="$1" \/>$turnstart/;
				}
print "BELLO ", __LINE__, " ", $turnopen,"\n";
				$turnopen = 1;
print "BELLO ", __LINE__, " ", $turnopen,"\n";
			}
			elsif ($coldict{$match}[0] eq "m") { # what comes after it, too
				my $type;
				if (@{$coldict{$match}} > 1) {$type = $coldict{$match}[1];} else {$type = $fullvalues{$coldict{$match}[0]};}
				my $number = $x =~ s/(?<!>)>\s*([A-Za-z]+):\s*([^<]*?)\s*(<ccline[^>]+>)?\s*([Bb][Yy][^<]*?)<ccline/><meta type="$type" value="$2 $4"><\/meta><ccline/; # This captures a frequent pattern over two cclines. If it fails, we use only the current ccline.
				if ($number < 1) {$x =~ s/(?<!>)>\s*([A-Za-z]+):\s*([^<]*?)\s*</><meta type="$type" value="$2" \/></;}
			}
			elsif (($coldict{$match}[0] eq "t") || ($coldict{$match}[0] eq "a")) { # what comes after it, too
				my $type = $fullvalues{$coldict{$match}[0]};
				my $description;
				if (@{$coldict{$match}} > 1) {$description = $coldict{$match}[1];} else {$description = $match;}
				$x =~ s/(?<!>)>\s*([A-Za-z]+):\s*(.*?)\s*</><meta type="$type" description="$description" value="$2" \/></;
			}
		}
	}

	# bracketed expressions
	# Basic idea:
	# 1. Work through the matches one by one.
	# 2. To avoid matching a previously matched item we can either remove the brackets or escape them with &lrb; &lsb; &rrb; &rsb;. -> Removal is probably best here.
	# 3. If escaped, unescape at the end.

	if (@matches = $x =~ /(?<!>)>\s*((?:\(|\[)\s*[^[(]*?\s*(?:\]|\)))/g) {
		foreach my $match (@matches) {
			next unless $brackdict{$match};
			my $type = $fullvalues{$brackdict{$match}[0]};
			my $originalvalue = $match;
			$originalvalue =~ s/^(\(|\[)\s*//;
			$originalvalue =~ s/\s*(\]|\))$//;
			my $closingturn = "";
			my $openingturn = "";
			if ($type eq "speakeridentification") {
				if ($turnopen == 1) {
					$closingturn = $turnend;
				}
				$openingturn = $turnstart;
				$turnopen = 1;
			}
			if (@{$brackdict{$match}} > 1) {
				my $value = $brackdict{$match}[1];
				$x =~ s/(?<!>)>\s*((?:\(|\[)\s*[^[(]*?\s*(?:\]|\)))/>$closingturn<meta type="$type" originalvalue="$originalvalue" value="$value" \/>$openingturn/;
			} else {
				$x =~ s/(?<!>)>\s*((?:\(|\[)\s*[^[(]*?\s*(?:\]|\)))/>$closingturn<meta type="$type" value="$originalvalue" \/>$openingturn/;
			}
		}
	}
	print $x,"\n";

}
