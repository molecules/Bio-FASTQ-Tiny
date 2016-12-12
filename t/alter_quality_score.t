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

# Distribution-specific modules
use lib 'lib';              # add 'lib' to @INC
use Bio::FASTQ::Tiny qw(process_fastq coderef_print_altered_quality);

my $EMPTY_STRING = q{};


my $filename = filename_for('input');
open(my $fh_out,'>', \my $result);
my $print_qual_plus_32 = coderef_print_altered_quality($fh_out, 32);

process_fastq($filename, $print_qual_plus_32); 
my $expected = string_from('expected');

is($result, $expected, 'Altered quality scores');


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
# Lines that start with a backslash require an additional backslash in front of them.
#------------------------------------------------------------------------

__DATA__
__[ input ]__
@HWI-ST538:168:XXXXXXXXX:4:1101:1214:1873 1:Y:0:
GCTGATGNAGCAGCTCTNCAGGACNGACCTTAGNNNCAACAAGTTTGAGNNGGATGTNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+
<#05=@?#2@@@@@??@#3@>@@@#1:=???<?###00<=???=??==?###################################################
@HWI-ST538:168:XXXXXXXXX:4:1101:1146:1888 1:Y:0:
TNCGTTTGCAGCCCGGGCAGCGTCCGGAGGATCGANCTGGTGGGCGGCGNNGTTGGGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+
<#0@-(:@@@@)@(((:=???/-<=???########################################################################
@HWI-ST538:168:XXXXXXXXX:4:1101:1414:1873 1:Y:0:
GCTGATGNAGCAGCTCTNCAGGACNGACCTTAGNNNCAACAAGTTTGAGNNGGATGTAGCTTCGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+
<#05=@?#2@@@@@??@#3@>@@@#1:=???<?###00<=???=??==?###################################################
__[ expected ]__
@HWI-ST538:168:XXXXXXXXX:4:1101:1214:1873 1:Y:0:
GCTGATGNAGCAGCTCTNCAGGACNGACCTTAGNNNCAACAAGTTTGAGNNGGATGTNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+
\\CPU]`_CR`````__`CS`^```CQZ]___\_CCCPP\]___]__]]_CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
@HWI-ST538:168:XXXXXXXXX:4:1101:1146:1888 1:Y:0:
TNCGTTTGCAGCCCGGGCAGCGTCCGGAGGATCGANCTGGTGGGCGGCGNNGTTGGGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+
\\CP`MHZ````I`HHHZ]___OM\]___CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
@HWI-ST538:168:XXXXXXXXX:4:1101:1414:1873 1:Y:0:
GCTGATGNAGCAGCTCTNCAGGACNGACCTTAGNNNCAACAAGTTTGAGNNGGATGTAGCTTCGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+
\\CPU]`_CR`````__`CS`^```CQZ]___\_CCCPP\]___]__]]_CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
