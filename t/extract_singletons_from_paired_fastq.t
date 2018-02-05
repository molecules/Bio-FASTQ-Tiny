#!/bin/env perl
use strict;
use warnings;
use autodie;
use v5.10;

# Core Perl modules
use File::Glob ':bsd_glob';
use File::Basename;
use File::Temp qw(tempfile);
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

# CPAN modules
use Test2::Bundle::Extended;
use Test2::Tools::Exception qw(dies);
use File::Slurp qw(write_file);

my $DEBUG = shift // 0;

{ # paired-end one adapter
    my $basename = "input_S1";
    my ($input_forward,$input_reverse) = gzipped_pair_of_files_for($basename);


    my $json_filename = json_filename_for("json_paired");
    
    my $std_out_err = `perl bin/extract_singletons_from_paired_fastq $input_forward $input_reverse 2 2>&1`;

    print $std_out_err if $DEBUG;

    my $final_forward     = "${basename}_R1_001.good_paired.fastq.gz";
    my $final_reverse     = "${basename}_R2_001.good_paired.fastq.gz";
    my $orphan_forward    = "${basename}_R1_001.orphans.fastq.gz";
    my $orphan_reverse    = "${basename}_R2_001.orphans.fastq.gz";

    my $result_forward    = `zcat $final_forward`;
    my $result_reverse    = `zcat $final_reverse`;
    my $result_orph_forw  = `zcat $orphan_forward`;
    my $result_orph_rev   = `zcat $orphan_reverse`;
    
    my $expected_forward   = string_for('expected_forward');
    my $expected_reverse   = string_for('expected_reverse');
    my $expected_orph_forw = string_for('expected_orph_forw');
    my $expected_orph_rev  = string_for('expected_orph_rev');
    
    is($result_forward,   $expected_forward,   "correctly created output forward paired file");
    is($result_reverse,   $expected_reverse,   "correctly created output reverse paired file");
    is($result_orph_forw, $expected_orph_forw, "correctly created output forward orphans file");
    is($result_orph_rev,  $expected_orph_rev,  "correctly created output reverse orphans file");
    
    # clean up temp files
    unlink $input_forward   unless $DEBUG;
    unlink $input_reverse   unless $DEBUG;
    unlink $final_forward   unless $DEBUG;
    unlink $final_reverse   unless $DEBUG;
    unlink $orphan_forward  unless $DEBUG;
    unlink $orphan_reverse  unless $DEBUG;
    unlink $json_filename   unless $DEBUG;
}

my @slurm_out_files = bsd_glob('slurm*.out'); 

unlink @slurm_out_files;

system('rm -rf job_files.dir');

done_testing;

sub string_for {
    my $section = shift;

    my %string_for = (


'input_S1_forward' => <<'END',
@A
AAAA
+
EEEE
@B

+

@C
AGCT
+
EEEE
@D
TTTT
+
EEEE
@E
AAAA
+
EEEE
@F
CCCC
+
EEEE
@G
AGCT
+
EEEE
@H
TTTT
+
EEEE
END

'input_S1_reverse' => <<'END',
@A
AAAAAGA
+
EEEEEEE
@B
CCCCAGA
+
EEEEEEE
@C
AGCTAGA
+
EEEEEEE
@D

+

@E
AAAAAGA
+
EEEEEEE
@F
CCCCAGA
+
EEEEEEE
@G
AGCTAGA
+
EEEEEEE
@H

+

END

'expected_forward' => <<'END',
@A
AAAA
+
EEEE
@C
AGCT
+
EEEE
@E
AAAA
+
EEEE
@F
CCCC
+
EEEE
@G
AGCT
+
EEEE
END

'expected_reverse' => <<'END',
@A
AAAAAGA
+
EEEEEEE
@C
AGCTAGA
+
EEEEEEE
@E
AAAAAGA
+
EEEEEEE
@F
CCCCAGA
+
EEEEEEE
@G
AGCTAGA
+
EEEEEEE
END

'expected_orph_forw' => <<'END',
@D
TTTT
+
EEEE
@H
TTTT
+
EEEE
END

'expected_orph_rev' => <<'END',
@B
CCCCAGA
+
EEEEEEE
END

'json_paired' => <<'END',
{
    "R1_adapters" : [ "GGGG" ],
    "R2_adapters" : [ "TTTT" ],
    "minimum-length" : 2,
    "MEMORY" : "10G",
    "paired_basenames": ["input_S1"]
}

END
    );

    die "section '$section' not found" if ! defined $string_for{$section};

    return $string_for{$section};
}

sub json_filename_for {
    my $section = shift;

    my $json_string = string_for($section);

    my $json_filename = "t/$section.json";
    write_file($json_filename, $json_string);
    return $json_filename;
}

sub gzipped_pair_of_files_for {
    my $base = shift;

    my $forward_section = "${base}_forward";
    my $reverse_section = "${base}_reverse";
    my $forward_name    = "${base}_R1_001.fastq";
    my $reverse_name    = "${base}_R2_001.fastq";
    
    my $forward_input = gzipped_file_for($forward_section,$forward_name);
    my $reverse_input = gzipped_file_for($reverse_section,$reverse_name);

    return ($forward_input, $reverse_input);
}

sub gzipped_file_for {
    my $section  = shift;
    my $filename = shift;

    write_file($filename,string_for($section));

    # create compressed file
    my $gzipped_name = "$filename.gz";
    system "gzip $filename";

    return $gzipped_name;
}
