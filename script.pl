#!/usr/bin/perl

use strict;
use warnings;

use JSON;
use Text::CSV;
use Getopt::Long;

{
    ## try to load Tie::IxHash
    my $ordered_hash = eval {require Tie::IxHash};

    my $output_format = "json";

    my $trim = 0;
    my $help = 0;

    GetOptions(
        "--help|h!"           => \$help,
        "--trim!" => \$trim,
    ) or display_help();
    display_help() if $help;

    ## use STDIN if file name is not specified
    my ($fn) = @ARGV;
    unless (defined $fn) {
        die "input file name is required";
    }

    my ($data) = read_data($fn, $ordered_hash, $trim);

    my $result = \*STDOUT;

    write_json($data, $result);

    if ($output_format eq 'self') {
        close($result);
    }
}

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


sub smart_file_type_detection {
    my ($file) = @_;

    ## FIX doen't work with STDIN
    open(my $fh, "<", $file) or die "can't read [$file]: $!";
    my $lines = "";
    my $count = 5;
    while (<$fh>) {
        $lines .= $_;
        last unless --$count;
    }
    close($fh);

    if ($lines =~ m/^\s*[{\]]/) {## "[" or "{"
        return ('json');
    }
    else {
        my ($first_line, $second_line, undef) = split(m{\r?\n}, $lines, 3);

        if (split(",", $first_line) == split(",", $second_line)) {
            return ('csv', ",");
        }
    }
    return;
}

sub read_data {
    my ($fn, $ordered_hash, $trim_whitespaces) = @_;

    my ($type_detected, $separator_detected) = smart_file_type_detection($fn);
    unless (defined $type_detected) {
        $type_detected = 'csv';
    }
    $separator_detected = ",";

    my $data = undef;
    if ($type_detected eq 'csv') {
        $data = read_csv($fn, $ordered_hash, $separator_detected, $trim_whitespaces);
    }
    unless (defined $data) {
        die "can't read $type_detected format from [$fn]";
    }
    return ($data);
}

sub read_csv {
    my ($fn, $ordered_hash, $separator, $trim_whitespaces) = @_;

    my $csv = Text::CSV->new(
    {
        'binary'           => 1,
        'sep_char'         => $separator,
        'allow_whitespace' => $trim_whitespaces,
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
