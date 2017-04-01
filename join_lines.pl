#!/usr/bin/perl

# This file takes as input the output of filter_metainfo_from_cclines.pl

use strict;
use utf8;
use open qw(:std :utf8); # This also works for the Diamond Operator
binmode STDOUT, ':utf8';

my $firstrun = 1;
while (my $x = <STDIN>) {
	chomp $x;
	if ($x eq '<?xml version="1.0" encoding="UTF-8"?>') {
		print $x;
		next;
	}
	my $y = $x;
	$y =~ s/<.*?>//g;
	unless ($y =~ /^\s*$/) {
		if ($firstrun == 1) {
			$firstrun = 0;
		}
		else {
			print "\n";
		}
	}
	print $x;
}
print "\n";