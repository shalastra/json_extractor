#!/usr/bin/perl

use strict;
use warnings;

use JSON;
use Text::CSV;
use Getopt::Long;

{
    ## try to load Tie::IxHash
    my $ordered_hash_available = eval { require Tie::IxHash };

    my $show_help = 0;
    my $write = "json";
    my $trim_whitespaces = 0;

    GetOptions(
        "--help|h!" => \$show_help,
        "--write=s" => \$write,
        "--trim-whitespaces!" => \$trim_whitespaces,
    ) or show_help();
    show_help() if $show_help;

    ## use STDIN if file name is not specified
    my ($fn) = @ARGV;
    unless (defined $fn) {
        die "input file name is required";
    }

    my ($data, $format) = smart_read_data($fn, $ordered_hash_available, $trim_whitespaces);

    my $output = \*STDOUT;
    if ($write eq 'self') {
        open($output, ">", $fn) or die "can't write [$fn]: $!";
    } else {
        $format = $write;
    }

    write_json($data, $output);

    if ($write eq 'self') {
        close($output);
    }
}

sub show_help {
    print "Usage: $0 [--write=json] [--trim-whitespaces] ".
        "[--help] <file>\n";
    exit(1);
}

sub smart_read_data {
    my ($fn, $ordered_hash_available, $trim_whitespaces) = @_;

    my ($type_detected, $separator_detected) = smart_file_type_detection($fn);
    unless (defined $type_detected) {
        $type_detected = 'csv';
    }
    $separator_detected = ",";


    my $data = undef;
    if ($type_detected eq 'csv') {
        $data = read_csv($fn, $ordered_hash_available, $separator_detected, $trim_whitespaces);
    } elsif ($type_detected eq 'table') {
        $data = read_table($fn, $ordered_hash_available, $trim_whitespaces);
    } elsif ($type_detected eq 'xlsx') {
        $data = read_xlsx($fn, $ordered_hash_available);
    }
    unless (defined $data) {
        die "can't read $type_detected format from [$fn]";
    }
    return ($data, $type_detected);
}

sub smart_file_type_detection {
    my ($file) = @_;

    ## FIX doen't work with STDIN
    open(my $fh, "<", $file) or die "can't read [$file]: $!";
    my $lines = "";
    my $count = 5;
    while (<$fh>) {
        $lines .= $_;
        last unless -- $count;
    }
    close($fh);

    if ($lines =~ m/^\s*[{\]]/) { ## "[" or "{"
        return ('json');
    } else {
        my ($first_line, $second_line, undef) = split(m{\r?\n}, $lines, 3);

        if (split(",", $first_line) == split(",", $second_line)) {
            return ('csv', ",");
        }
    }
    return;
}

sub write_json {
    my ($data, $output) = @_;

    print $output to_json(
        $data,
        {
            'utf8' => 1,
            'pretty' => 1,
        }
    );
}

sub read_csv {
    my ($fn, $ordered_hash_available, $separator, $trim_whitespaces) = @_;

    my $csv = Text::CSV->new(
        {
            'binary' => 1,
            'sep_char' => $separator,
            'allow_whitespace' => $trim_whitespaces,
        }
    ) or die "can't create Text::CSV: ".Text::CSV->error_diag();

    open(my $fh, "<", $fn) or die "can't read [$fn]: $!";
    binmode($fh, ":utf8");
    my ($columns, @rows);
    while ( my $row = $csv->getline( $fh ) ) {
        if (defined $columns) {
            my %r;
            if ($ordered_hash_available) {
                tie %r, "Tie::IxHash";
            }
            @r{@$columns} = @$row;
            push(@rows, \%r);
        } else {
            $columns = $row;
        }
    }

    close($fh);

    return \@rows;
}