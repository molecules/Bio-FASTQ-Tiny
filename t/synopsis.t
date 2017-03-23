use 5.008;    # Require at least Perl version 5.8
use strict;   # Must declare all variables before using them
use warnings; # Emit helpful warnings
use autodie;  # Fatal exceptions for common unrecoverable errors (e.g. w/open)

# Testing-related modules
use Test::More;                  # provide testing functions (e.g. is, like)
use Data::Section -setup;        # Set up labeled DATA sections
use File::Temp  qw( tempfile );  #
use File::Slurp qw( slurp    );  # Read a file into a string
use Carp        qw( croak    );  # Push blame for errors back to line calling function

use lib 'lib';    # add 'lib' to @INC

use Bio::IRCF::FASTQ::Tiny qw( process_fastq to_fasta);

{
    open( my $fh_out, '>', \my $result );

    my $make_fasta_coderef = sub {
        my $entry_href = shift // return;  # Explicit return for undefined value

        print {$fh_out} '>' . $entry_href->{header} . "\n";
        print {$fh_out} $entry_href->{seq} . "\n";
        return 1;
    };

    my $filename = filename_for('input');

    process_fastq( $filename, $make_fasta_coderef );

    my $expected = string_from('expected');

    is( $result, $expected, 'Synopsis example should work' );
}

{
    open( my $fh_out, '>', \my $result );

    my $filename = filename_for('input');

    to_fasta( $filename, $fh_out );

    my $expected = string_from('expected');

    is( $result, $expected, 'to_fasta works' );
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

    # Don't overwrite existing file
    croak "'$filename' already exists." if -e $filename;

    my $string   = string_from($section);
    open(my $fh, '>', $filename);
    print {$fh} $string;
    close $fh;
    return;
}

sub filename_for {
    my $section           = shift;
    my ( $fh, $filename ) = tempfile();
    my $string            = string_from($section);
    print {$fh} $string;
    close $fh;
    return $filename;
}

sub temp_filename {
    my ($fh, $filename) = tempfile();
    close $fh;
    return $filename;
}

sub delete_temp_file {
    my $filename  = shift;
    my $delete_ok = unlink $filename;
    ok($delete_ok, "deleted temp file '$filename'");
    return;
}

#------------------------------------------------------------------------
# IMPORTANT!
#
# Each line from each section automatically ends with a newline character
#------------------------------------------------------------------------

__DATA__
__[ input ]__
@HWI-ST538:168:XXXXXXXXX:4:1101:1214:1873 1:Y:0:
GCTGATGNAGCAGCTCTNCAGGACNGACCTTAGNNNCAACAAGTTTGAGNNGGATGTNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+
@#05=@?#2@@@@@??@#3@>@@@#1:=???<?###00<=???=??==?###################################################
@HWI-ST538:168:XXXXXXXXX:4:1101:1146:1888 1:Y:0:
TNCGTTTGCAGCCCGGGCAGCGTCCGGAGGATCGANCTGGTGGGCGGCGNNGTTGGGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+
<#0@-(:@@@@)@(((:=???/-<=???########################################################################
@HWI-ST538:168:XXXXXXXXX:4:1101:1414:1873 1:Y:0:
GCTGATGNAGCAGCTCTNCAGGACNGACCTTAGNNNCAACAAGTTTGAGNNGGATGTAGCTTCGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+
<#05=@?#2@@@@@??@#3@>@@@#1:=???<?###00<=???=??==?###################################################
__[ expected ]__
>HWI-ST538:168:XXXXXXXXX:4:1101:1214:1873 1:Y:0:
GCTGATGNAGCAGCTCTNCAGGACNGACCTTAGNNNCAACAAGTTTGAGNNGGATGTNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
>HWI-ST538:168:XXXXXXXXX:4:1101:1146:1888 1:Y:0:
TNCGTTTGCAGCCCGGGCAGCGTCCGGAGGATCGANCTGGTGGGCGGCGNNGTTGGGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
>HWI-ST538:168:XXXXXXXXX:4:1101:1414:1873 1:Y:0:
GCTGATGNAGCAGCTCTNCAGGACNGACCTTAGNNNCAACAAGTTTGAGNNGGATGTAGCTTCGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
