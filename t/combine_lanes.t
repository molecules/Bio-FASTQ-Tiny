#!/bin/env perl
use 5.010;      # Require at least Perl version 5.10
use strict;     # Must declare all variables before using them
use warnings;   # Emit helpful warnings
use autodie;    # Fatal exceptions for common unrecoverable errors (e.g. w/open)

# Testing-related modules
use Test::More;                 # provide testing functions (e.g. is, like)
use Data::Section -setup;       # Set up labeled DATA sections
use File::Temp  qw( tempfile ); # Function to create a temporary file
use File::Slurp qw( slurp    ); # Function to read a file into a string
use Carp        qw( croak    ); # Function to emit errors that blame the calling code


{
    chdir 't';

    assign_filename_for('sample_L001_R1_001.fastq','fastq_L001_R1');
    assign_filename_for('sample_L002_R1_001.fastq','fastq_L002_R1');
    assign_filename_for('sample_L001_R2_001.fastq','fastq_L001_R2');
    assign_filename_for('sample_L002_R2_001.fastq','fastq_L002_R2');

    system("../bin/combine_lanes");

    my $out_R1 = 'sample_R1_001.fastq';
    my $out_R2 = 'sample_R2_001.fastq';

    my $result1 = slurp($out_R1);
    my $expected1 = string_from('fastq_combined_R1');
    is($result1, $expected1, 'combined FASTQ files (forward)');

    my $result2 = slurp($out_R2);
    my $expected2 = string_from('fastq_combined_R2');
    is($result2, $expected2, 'combined FASTQ files (reverse)');

    # Clean up temp files
    
    unlink 'sample_L001_R1_001.fastq';
    unlink 'sample_L002_R1_001.fastq';
    unlink 'sample_R1_001.fastq';

    unlink 'sample_L001_R2_001.fastq';
    unlink 'sample_L002_R2_001.fastq';
    unlink 'sample_R2_001.fastq';

    system("rm *sbatch*");
}


done_testing();


sub sref_from {
    my $section = shift;

    #Scalar reference to the section text
    return __PACKAGE__->section_data($section);
}

sub string_from {
    my $section = shift;

    #Get the scalar reference
    my $sref = sref_from($section);

    #Return a string containing the entire section
    return ${$sref};
}

sub fh_from {
    my $section = shift;
    my $sref    = sref_from($section);

    #Create filehandle to the referenced scalar
    open( my $fh, '<', $sref );
    return $fh;
}

sub assign_filename_for {
    my $filename = shift;
    my $section  = shift;

    my $string = string_from($section);
    open( my $fh, '>', $filename );
    print {$fh} $string;
    close $fh;
    return;
}

sub filename_for {
    my $section = shift;
    my ( $fh, $filename ) = tempfile();
    my $string = string_from($section);
    print {$fh} $string;
    close $fh;
    return $filename;
}

sub temp_filename {
    my ( $fh, $filename ) = tempfile();
    close $fh;
    return $filename;
}

sub delete_temp_file {
    my $filename  = shift;
    my $delete_ok = unlink $filename;
    ok( $delete_ok, "deleted temp file '$filename'" );
}

__DATA__
__[ fastq_L001_R1 ]__
@A
AAAA
+
EEEE
@B
CCCC
+
EEEE
__[ fastq_L002_R1 ]__
@C
GGGG
+
EEEE
__[ fastq_combined_R1 ]__
@A
AAAA
+
EEEE
@B
CCCC
+
EEEE
@C
GGGG
+
EEEE
__[ fastq_L001_R2 ]__
@A
TTTT
+
EEEE
@B
CCCC
+
EEEE
__[ fastq_L002_R2 ]__
@C
ACGT
+
EEEE
__[ fastq_combined_R2 ]__
@A
TTTT
+
EEEE
@B
CCCC
+
EEEE
@C
ACGT
+
EEEE
