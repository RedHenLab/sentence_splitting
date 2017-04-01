#!/usr/bin/perl

# This files takes as input the output from sentence_splitting.py


use strict;
use Data::Dumper;
use utf8;
use open qw(:std :utf8); # This also works for the Diamond Operator
binmode STDOUT, ':utf8';

# Path to dictionaries
my $dictpath = "/home/pruhrig/sentence_splitting/";

# LOADING RESOURCES

# Set the abbreviations in the dictionaries
my %fullvalues = (
	"s" => "speakeridentification",
	"a" => "audio_description", # including silence
	"f" => "foreign_language", # not English
	"l" => "lyrics", # music with words
	"m" => "music", # music without words (can have words, but the lyrics are not in the captions)
	"o" => "orientation", # orienting information -- meta-information about the program (END CLIP)
	"p" => "paralinguistic_signal", # applause, laugh, sigh, hiss
	"q" => "quality_of_expression", # unenthusiastic, sheepishly, proudly, nervously
	"s" => "speaker_identification", # (John, woman, captain)
	"t" => "on-screen_text_repeated_in_captions" # (seems to occur only on WWW_Russia so far)
#	"u" => "undetermined", # Should this be here, actually?
#	"n" => "not in brackets" # (mistaken entry)
#	"i" => "ignore", # the term is spoken
);


# Word with colon
my %coldict;
open(my $cfh, "<:encoding(UTF-8)", $dictpath."words_with_colons_dictionary.txt") or die "Can't open < words_with_colons_dictionary.txt: $!";
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
	open(my $bfh, "<:encoding(UTF-8)", $dictpath.$filename) or die "Can't open < $filename: $!";
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

# MAIN LOOP
print '<?xml version="1.0" encoding="UTF-8"?>',"\n";
while (my $x = <>) {
	chomp $x;
	$x =~ s/\x00//g;
	$x =~ s/\x02//g;
	$x =~ s/\x03//g;
	$x =~ s/\x06//g;
	$x =~ s/\x0F//g;
	$x =~ s/\x1B//g;
	$x =~ s/\x19/&apos;/g;

	# First let's get rid of the first and last line with the text-tags.
	if ($x =~ /^<\/?text/) {
		print $x,"\n";
		next;
	}
	# Not yet quite sure why the following line is there. Took it over from the Python version, so I must have seen the need somewhere.
#	$x =~ s/&/&amp;/g;
	
	my @matches = ();



	# Story boundary
	$x =~ s/(?<=>)(\s*&gt;&gt;&gt;\s*)+/<storyboundary \/>/g;
	# Story boundary EOL
	$x =~ s/(?<!("|'|\/))(?:\s*&gt;&gt;&gt;\s*)+<\/ccline/\n<storyboundary \/><\/ccline/g;
	# Turn boundary
	$x =~ s/(?<=>)(\s*&gt;&gt;\s*)+/<turnboundary \/>/g;
	# Turn boundary EOL
	#$x =~ s/(?<!(&quot;|&apos;|\/))(?:\s*&gt;&gt;\s*)+<\/ccline/\n<turnboundary \/><\/ccline/g;
	# When XML entities were introduced, the previous line generated an error with variable length lookbehinds not being implemented, that is why it was split up into the following two lines:
	$x =~ s/(?<!(&quot;|&apos;))(?:\s*&gt;&gt;\s*)+<\/ccline/\n<turnboundary \/><\/ccline/g;
	$x =~ s/(?<!(\/))(?:\s*&gt;&gt;\s*)+<\/ccline/\n<turnboundary \/><\/ccline/g;
	# Story boundary inline
	$x =~ s/(?<!>)\s*&gt;&gt;&gt;\s+/\n<storyboundary \/>/g;
	# Turn boundary inline
	#$x =~ s/(?<!(&quot;|&apos;|\/))\s*&gt;&gt;\s+/\n<turnboundary \/>/g;
	# When XML entities were introduced, the previous line generated an error with variable length lookbehinds not being implemented, that is why it was split up into the following two lines:
	$x =~ s/(?<!(&quot;|&apos;))\s*&gt;&gt;\s+/\n<turnboundary \/>/g;
	$x =~ s/(?<!(\/))\s*&gt;&gt;\s+/\n<turnboundary \/>/g;
	# Turn boundary one chevron only
	$x =~ s/(?<!>)(?:>\s*&gt;\s*)+/>\n<turnboundary \/>/g;
	# Musical Notes:
	$x =~ s/(♪+)/<musicalnotes value="$1" \/>/g;


	my $linewithoutcctags = $x;
	$linewithoutcctags =~ s/<\/?ccline[^<>]+>//g;
	$linewithoutcctags =~ s/^\s*//;
	$linewithoutcctags =~ s/\s*$//;
#	print "XXXXXXXXX", $linewithoutcctags, "\n";
	if (($linewithoutcctags =~ /<storyboundary \/>/) && ($linewithoutcctags !~ /^<storyboundary \/>/)) {
		$x =~ s/<storyboundary \/>/\n<storyboundary \/>/;
	}
	if (($linewithoutcctags =~ /<turnboundary \/>/) && ($linewithoutcctags !~ /^<turnboundary \/>/)) {
		$x =~ s/<turnboundary \/>/\n<turnboundary \/>/;
	}

	# words with colons
	if (@matches = $x =~ /(?<!>)>\s*([A-Za-z]+):\s*/g) {
		foreach my $match (@matches) {
			next unless $coldict{$match};
			if ($coldict{$match}[0] eq "s") { # only the item itself
				if (@{$coldict{$match}} > 1) {
					my $value = $coldict{$match}[1];
					$x =~ s/(?<!>)>\s*([A-Za-z]+):\s*/><meta type="speakeridentifcation" original_value="$1" value="$value" \/>/;
				}
				else {
					$x =~ s/(?<!>)>\s*([A-Za-z]+):\s*/><meta type="speakeridentifcation" value="$1" \/>/;
				}
			}
			elsif ($coldict{$match}[0] eq "m") { # what comes after it, too
				my $type;
				if (@{$coldict{$match}} > 1) {$type = $coldict{$match}[1];} else {$type = $fullvalues{$coldict{$match}[0]};}
				my $number = $x =~ s/(?<!>)>\s*([A-Za-z]+):\s*([^<]*?)\s*(<\/ccline>\s*<ccline[^>]+>)?\s*([Bb][Yy][^<]*?)<\/ccline>/><meta type="$type" value="$2 $4" \/><\/ccline>/; # This captures a frequent pattern over two cclines. If it fails, we use only the current ccline.
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
#			print "BELLO $match\n";
			next unless $brackdict{$match};
#			print "BELLO2\n";
			my $type = $fullvalues{$brackdict{$match}[0]};
			my $originalvalue = $match;
			$originalvalue =~ s/^(\(|\[)\s*//;
			$originalvalue =~ s/\s*(\]|\))$//;
			if (@{$brackdict{$match}} > 1) {
				my $value = $brackdict{$match}[1];
				$x =~ s/(?<!>)>\s*((?:\(|\[)\s*[^[(]*?\s*(?:\]|\)))/><meta type="$type" originalvalue="$originalvalue" value="$value" \/>/;
			} else {
				$x =~ s/(?<!>)>\s*((?:\(|\[)\s*[^[(]*?\s*(?:\]|\)))/><meta type="$type" value="$originalvalue" \/>/;
			}
		}
	}

	print $x;

	# We should only print a newline if the line contains an actual sentence. CoreNLP relies on having one sentence per line and will simply ignore the annotations if they are not on the same line as a sentence.
	# Replace all XML tags with nothing:
	$x =~ s/<.*?>//g;
	# If not only non-word-characters are left, we print a newline.
	unless ($x =~ /^\W*$) {print "\n";}

}