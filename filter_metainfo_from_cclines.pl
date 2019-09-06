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
	#print "BELLO INLINE: $x\n";

	# Add turn tags after opening and before closing segment
	if ($x =~ /^<\/?segment/) {
		if ($x =~ /<segment/) {
			$x .= $turnstart;
#print "BELLO ", __LINE__, "\n";
		}

		if ($x =~ /<\/segment>/) {
			$x =~ s/<\/segment>/$turnend<\/segment>/;
		}
		print $x,"\n";
		next;
	}
	# Not yet quite sure why the following line is there. Took it over from the Python version, so I must have seen the need somewhere.
#	$x =~ s/&/&amp;/g;
	
	my @matches = ();


#print "BELLO ", __LINE__, "\n";
	# Story boundary
	# Close open tag and open a new one for every occurrence
	$x =~ s/(?<=>)(\s*&gt;&gt;&gt;\s*)+/$storyend$storystart/g;

#print "BELLO ", __LINE__, "\n";
	# Story boundary inline
	# Close open tag and open a new one for every occurrence
	$x =~ s/(?<!>)\s*&gt;&gt;&gt;\s+/\n$storyend$storystart/g;

#print "BELLO ", __LINE__, "\n";
	# Story boundary EOL
	# Close open tag and open a new one for every occurrence
	$x =~ s/(?<!("|'|\/))(?:\s*&gt;&gt;&gt;\s*)+<ccline/\n$storyend$storystart<ccline/g;

#print "BELLO ", __LINE__, "\n";
	# Turn boundary
	# Close open tag and open a new one for every occurrence
	$x =~ s/(?<=>)(\s*&gt;&gt;\s*)+/$turnend$turnstart/g;

#print "BELLO ", __LINE__, "\n";
	# Turn boundary inline
	$x =~ s/(?<!(&quot;|&apos;))\s*&gt;&gt;\s+/\n$turnend$turnstart/g;
	$x =~ s/(?<!(\/))\s*&gt;&gt;\s+/\n$turnend$turnstart/g;

#print "BELLO ", __LINE__, "\n";
	# Turn boundary EOL
	$x =~ s/(?<!(&quot;|&apos;))(?:\s*&gt;&gt;\s*)+<ccline/\n$turnend$turnstart<ccline/g;
	$x =~ s/(?<!(\/))(?:\s*&gt;&gt;\s*)+<ccline/\n$turnend$turnstart<ccline/g;

#print "BELLO ", __LINE__, "\n";
	# Turn boundary one chevron only
	$x =~ s/(?<!>)(?:>\s*&gt;\s*)+/>\n$turnend$turnstart/g;

#print "BELLO ", __LINE__, "\n";
	# Musical Notes:
	$x =~ s/(♪+)/<musicalnotes value="$1" \/>/g;


	my $linewithoutcctags = $x;
	$linewithoutcctags =~ s/<\/?ccline[^<>]+>//g;
	$linewithoutcctags =~ s/^\s*//;
	$linewithoutcctags =~ s/\s*$//;
#	print "XXXXXXXXX", $linewithoutcctags, "\n";
	if (($linewithoutcctags =~ /$storystart/) && ($linewithoutcctags !~ /^$storystart/)) {
#print "BELLO ", __LINE__, "\n";
		$x =~ s/$storystart/\n$storystart/;
	}
	if (($linewithoutcctags =~ /$turnstart/) && ($linewithoutcctags !~ /^$turnstart/)) {
#print "BELLO ", __LINE__, "\n";
		$x =~ s/$turnstart/\n$turnstart/;
	}

	# words with colons
	if (@matches = $x =~ /(?<!>)>\s*([A-Za-z]+):\s*/g) {
		foreach my $match (@matches) {
			next unless $coldict{$match};
			if ($coldict{$match}[0] eq "s") { # only the item itself
				if (@{$coldict{$match}} > 1) {
					my $value = $coldict{$match}[1];
					$x =~ s/(?<!>)>\s*([A-Za-z]+):\s*/>$turnend<meta type="speakeridentification" originalvalue="$1" value="$value" \/>$turnstart/;
#print "BELLO ", __LINE__, "\n";
				}
				else {
					$x =~ s/(?<!>)>\s*([A-Za-z]+):\s*/>$turnend<meta type="speakeridentification" value="$1" \/>$turnstart/;
#print "BELLO ", __LINE__, "\n";
				}
			}
			elsif ($coldict{$match}[0] eq "m") { # what comes after it, too
				my $type;
				if (@{$coldict{$match}} > 1) {$type = $coldict{$match}[1];} else {$type = $fullvalues{$coldict{$match}[0]};}
				my $number = $x =~ s/(?<!>)>\s*([A-Za-z]+):\s*([^<]*?)\s*(<ccline[^>]+>)?\s*([Bb][Yy][^<]*?)<ccline/><meta type="$type" value="$2 $4" \/><ccline/; # This captures a frequent pattern over two cclines. If it fails, we use only the current ccline.
				if ($number < 1) {$x =~ s/(?<!>)>\s*([A-Za-z]+):\s*([^<]*?)\s*</><meta type="$type" value="$2" \/></;}
#print "BELLO ", __LINE__, "\n";
			}
			elsif (($coldict{$match}[0] eq "t") || ($coldict{$match}[0] eq "a")) { # what comes after it, too
				my $type = $fullvalues{$coldict{$match}[0]};
				my $description;
				if (@{$coldict{$match}} > 1) {$description = $coldict{$match}[1];} else {$description = $match;}
				$x =~ s/(?<!>)>\s*([A-Za-z]+):\s*(.*?)\s*</><meta type="$type" description="$description" value="$2" \/></;
#print "BELLO ", __LINE__, "\n";
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
				$closingturn = $turnend;
				$openingturn = $turnstart;
#print "BELLO ", __LINE__, "\n";
			}
			if (@{$brackdict{$match}} > 1) {
				my $value = $brackdict{$match}[1];
				$x =~ s/(?<!>)>\s*((?:\(|\[)\s*[^[(]*?\s*(?:\]|\)))/>$closingturn<meta type="$type" originalvalue="$originalvalue" value="$value" \/>$openingturn/;
#print "BELLO ", __LINE__, "\n";
			} else {
				$x =~ s/(?<!>)>\s*((?:\(|\[)\s*[^[(]*?\s*(?:\]|\)))/>$closingturn<meta type="$type" value="$originalvalue" \/>$openingturn/;
#print "BELLO ", __LINE__, "\n";
			}
		}
	}
	print $x,"\n";

}
