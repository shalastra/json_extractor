#!/usr/bin/perl

use autodie;
use strict;
use utf8;
use warnings qw(all);

use Getopt::Long;
use Pod::Usage;

# VERSION

=head1 SYNOPSIS

    Script takes one file as a first argument. Next arguments are names
    which should be extracted, i.e.:
            perl script.pl <filename> <arg1>...<argN>

=head1 DESCRIPTION

...

=cut

GetOptions(
    q(help)             => \my $help
);
pod2usage(q(-verbose) => 1) if $help;

# Actual code below

my $lineno = 1;
my $current = "";

while(<>) {
    if($current ne $ARGV) {
        $current = $ARGV;
        print "\n\t\tFile: $ARGV\n\n";
        $lineno = 1;
    }

    print $lineno++;
    print ": $_";
}