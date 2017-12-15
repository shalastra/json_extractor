#!/usr/bin/perl

#IMPORTS
use strict;
use warnings;

use JSON;
use Text::CSV;
use Getopt::Long;

#Main functionality
{
    my $ordered_hash = eval {require Tie::IxHash};

    # Defined output format
    my $output_format = "json";

    my $trim = 0;
    my $help = 0;

    # List of available options in script, passed as an argument during execution
    GetOptions(
        "--help|h!"           => \$help,
        "--trim!" => \$trim,
    ) or display_help();
    display_help() if $help;

    my ($fn) = @ARGV;
    unless (defined $fn) {
        die "input file name is required";
    }

    # Reading data from a defined file
    my ($data) = read_data($fn, $ordered_hash, $trim);

    my $result = \*STDOUT;

    # Prints JSON in console
    write_json($data, $result);

    if ($output_format eq 'self') {
        close($result);
    }
}

#Responsible for displaying help
sub display_help {
    print "This script gives an user possibility to convert CSV to JSON. \n" .
        "To run execute this script and as an argument pass the name of csv file, i.e.:\n\n" .
        "   ./script SacramentocrimeJanuary2006.csv \n\n" .
        "As an output, converted JSON will be printed.\n" .
        "To save to new file, simply use tee command, i.e.:\n\n" .
        "   ./script SacramentocrimeJanuary2006.csv | tee <filename>.json\n\n" .
        "Additional arguments:\n" .
        "[--trim] - removes whitespaces from an output.\n" .
        "[--help, -h] - prints this help.\n" .
        "\n";
    exit(1);
}

# Returns type of a passed file, possible to extend
sub recognize_filetype {
    my ($file) = @_;

    open(my $fh, "<", $file) or die "can't read [$file]: $!";
    my $lines = "";
    my $count = 5;
    while (<$fh>) {
        $lines .= $_;
        last unless --$count;
    }
    close($fh);

    if ($lines =~ m/^\s*[{\]]/) {## "[" or "{"
        print "You cannot convert json to json";
        return ('json');
    }
    else {
        my ($first_line, $second_line, undef) = split(m{\r?\n}, $lines, 3);

        if (split(",", $first_line) == split(",", $second_line)) {
            return ('csv', ",");
        }
    }

    print "Cannot recognize filetype.";

    return;
}

# Reads data from a spedified file
sub read_data {
    my ($fn, $ordered_hash, $trim_whitespaces) = @_;

    my ($format, $separator) = recognize_filetype($fn);
    unless (defined $format) {
        $format = 'csv';
    }
    $separator = ",";

    my $data = undef;
    if ($format eq 'csv') {
        $data = read_csv($fn, $ordered_hash, $separator, $trim_whitespaces);
    }
    unless (defined $data) {
        die "can't read $format format from [$fn]";
    }
    return ($data);
}

# If it is a csv file, reads it
sub read_csv {
    my ($fn, $ordered_hash, $separator, $trim) = @_;

    my $csv = Text::CSV->new(
    {
        'binary'           => 1,
        'sep_char'         => $separator,
        'allow_whitespace' => $trim,
    }
    ) or die "can't create Text::CSV: " . Text::CSV->error_diag();

    open(my $fh, "<", $fn) or die "can't read [$fn]: $!";
    binmode($fh, ":utf8");
    my ($columns, @rows);
    while (my $row = $csv->getline($fh)) {
        if (defined $columns) {
            my %r;
            if ($ordered_hash) {
                tie %r, "Tie::IxHash";
            }
            @r{@$columns} = @$row;
            push(@rows, \%r);
        }
        else {
            $columns = $row;
        }
    }

    close($fh);

    return \@rows;
}

#Prints JSON from read CSV
sub write_json {
    my ($data, $output) = @_;

    print $output to_json(
        $data,
        {
            'utf8'   => 1,
            'pretty' => 1,
        }
    );
}
