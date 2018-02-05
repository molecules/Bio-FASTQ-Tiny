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

use Bio::IRCF::FASTQ::Tiny qw(process_fastq);

my $SUCCESS = 1;

{
    my $filename = filename_for('input');

    my $href = {};
    process_fastq($filename, summarize_coderef($href));

    is_deeply( $href, expected_summary(), 'summary is correct' );
}


done_testing();

sub expected_summary {
    return {
        lengths => {
            '4' => 2,
            '5' => 1,
            '8' => 2,
        },
    };
}

sub summarize_coderef {
    my $href = shift;
    
    return sub {
        my $entry_href = shift;
        return unless defined $entry_href;
        my $length = length($entry_href->{seq});
        $href->{lengths}{$length}++;
        return $SUCCESS;
    }
}

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
@A
AAAA
+
@#05
@B
CCCCC
+
<#0@-
@C
GGGG
+
<#0-
@D
TTTTTTTT
+
<#05=@?#
@E
TTTTTTTT
+
<#05=@?#
