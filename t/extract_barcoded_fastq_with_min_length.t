#!/bin/env perl
use strict;
use warnings;
use autodie;
use v5.10;

use Test::More;

use File::Slurper qw( read_text );

chdir 't';

system('../bin/extract_barcoded_fastq_with_min_length sample_with_barcodes.fastq barcodes 50');

system('gunzip -c sample_with_barcodes.fastq.barcode_filtered.fastq.gz > result.fastq');
system('gunzip -c sample_with_barcodes.fastq.unmatched.fastq.gz > unmatched.fastq');

my $result = read_text( 'result.fastq');

my $expected = read_text ( 'expected_with_barcodes.fastq' );

is($result, $expected, 'Correctly filterd FASTQ file');

unlink 'sample_with_barcodes.fastq.unmatched.fastq.gz';
unlink 'sample_with_barcodes.fastq.barcode_filtered.fastq.gz';
unlink 'result.fastq';
unlink 'unmatched.fastq';


done_testing();

