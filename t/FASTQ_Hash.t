#!/bin/env perl
use strict;
use warnings;
use v5.10;
use autodie;

use Test::More;

use lib 'lib';

my $result = `bin/FASTQ_Hash t/hello.fastq.gz t/howdy.fastq.gz`;

my $expected = `bin/FASTQ_Hash t/expected.fastq.gz`; 

is($result, $expected, "Correctly hashed two files same as combined file");

my $bad_result = `bin/FASTQ_Hash t/hello.fastq.gz`;

ok(! ($bad_result eq $expected), 'Hashing one file is not the same as hashing it plus another');

done_testing();
