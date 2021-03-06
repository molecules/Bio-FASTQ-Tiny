#!/bin/env perl
use strict;
use warnings;
use v5.10;
use autodie;

use Bio::IRCF::FASTQ::Tiny qw(process_fastq);
use Digest::MD5 qw(md5_base64);

my @files = @ARGV;

exit unless @files;

my @md5s_all;

for my $file (@files)
{
    my @md5s_in_file;

    my $coderef = sub {
        my $href    = shift;

        my $cluster = (split /\s+/, $href->{header})[0];
        my $md5     = md5_base64($cluster, $href->{seq}, $href->{qual});

        push @md5s_in_file, $md5;
    };

    process_fastq($file, $coderef);

    my $md5_file = md5_base64(sort @md5s_in_file);

    warn "# $file ($md5_file)\n";
    push @md5s_all, @md5s_in_file;
}

# Calculate hash of individual record hashes
my @md5s_sorted = sort @md5s_all;

my $fastq_hash  = md5_base64(@md5s_sorted);

warn "# Combined FASTQ Hash: $fastq_hash\n";

say $fastq_hash;
