#!/usr/bin/perl

# This file takes as input the output of filter_metainfo_from_cclines.pl

use strict;
use utf8;
use open qw(:std :utf8); # This also works for the Diamond Operator
binmode STDOUT, ':utf8';

my $lastx;
my $firstrun = 1;
while (my $x = <STDIN>) {
	chomp $x;
	if ($x eq '<?xml version="1.0" encoding="UTF-8"?>') {
		print $x;
		next;
	}
	my $y = $x;
	$y =~ s/<.*?>//g;
	unless ($y =~ /^\s*$/) { # If line contains something other than XML tags and whitespace, we print a newline, but not in the first run. [Why not in the first run??]
		if ($firstrun == 1) {
			$firstrun = 0;
		}
		else {
			print "\n";
		}
	}
	
	### FIX FOR ERROR IN CORENLP 3.7.0 discussed here: https://github.com/stanfordnlp/CoreNLP/issues/401
	if (($lastx =~ /_$/) && ($x =~ /^</)) {print " ";}
	$x =~ s/_</_ </g; 
	### END FIX (and $lastx becomes unnecessary when the fix is removed)
	
	print $x;
	$lastx = $x;
}
print "\n";