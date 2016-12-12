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

# Distribution-specific
use lib 'lib';             # add 'lib' to @INC
use Bio::FASTQ::Tiny qw( coderef_print_barcoded_entry
                    coderef_print_entry
                    iterator
                    process_fastq);

my $EMPTY_STRING = q{};
my $SUCCESS = 1;

{   # TEST FASTQ iterator

    #open( my $fh_gunzip, '-|', "gunzip -c t/fastq.gz" );
    my $filename = filename_for('fastq_GCT TNC');

    my $fastq_iterator = iterator( $filename, \&count_of_nucleotides );

    my @expected = (
        { A => 13, C => 10, G => 15, N => 51, T => 11, },
        { A => 5,  C => 13, G => 25, N => 47, T => 10, },
        { A => 14, C => 12, G => 17, N => 44, T => 13, },
    );

    # Get results of iterator run iterator 10 times.
    my @result = map { $fastq_iterator->() } 0 .. 10; # Iterations after EOF will be undefined

    is_deeply( \@result, \@expected, "Used custom coderef for iterator");

    # Delete temp file
    unlink($filename);
}

{   # Test default iterator 

    # Create default iterator (it returns a hash for each entry)
    my $filename       = filename_for('fastq_GCT TNC');
    my $fastq_iterator = iterator($filename);

    # Create filehandle to string for output
    open( my $fh_out, '>', \my $result );

    # Create a coderef which prints each FASTQ entry
    my $print_entry = Bio::FASTQ::Tiny::coderef_print_entry($fh_out);

    my @expected = (
        { header   => 'HWI-ST538:168:XXXXXXXXX:4:1101:1214:1873 1:Y:0:',
          seq      => 'GCTGATGNAGCAGCTCTNCAGGACNGACCTTAGNNNCAACAAGTTTGAGNNGGATGTNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN',
          q_header => $EMPTY_STRING,
          qual     => '<#05=@?#2@@@@@??@#3@>@@@#1:=???<?###00<=???=??==?###################################################',
        },
        { header   => 'HWI-ST538:168:XXXXXXXXX:4:1101:1146:1888 1:Y:0:',
          seq      => 'TNCGTTTGCAGCCCGGGCAGCGTCCGGAGGATCGANCTGGTGGGCGGCGNNGTTGGGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN',
          q_header => $EMPTY_STRING,
          qual     => '<#0@-(:@@@@)@(((:=???/-<=???########################################################################',
        },
        { header   => 'HWI-ST538:168:XXXXXXXXX:4:1101:1414:1873 1:Y:0:',
          seq      => 'GCTGATGNAGCAGCTCTNCAGGACNGACCTTAGNNNCAACAAGTTTGAGNNGGATGTAGCTTCGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN',
          q_header => $EMPTY_STRING,
          qual     => '<#05=@?#2@@@@@??@#3@>@@@#1:=???<?###00<=???=??==?###################################################',
        },
    );

    my @result;

    LOOP:
    while (1) {

        # get next FASTQ entry
        my $entry_href = $fastq_iterator->();

        # Exit if none found
        last LOOP if !defined $entry_href;

        # Add this entry to our collection
        push @result, $entry_href;
    }

    is_deeply( \@result, \@expected, 'Simple read of FASTQ file' );

    # Delete temp file
    unlink($filename);
}

{ # Test process_fastq with coderef_print_barcodeded_entry
                                    # Test multiple barcode string as well
    for my $barcode (qw( GCT TNC), 'GCT TNC') {    # you'd never see N in a real barcode, of course

        # Create filehandle to string for output
        open( my $fh_out, '>', \my $result );

        # Create a coderef which prints out a FASTQ entry if it matches a specific barcode
        my $print_barcoded_entry = Bio::FASTQ::Tiny::coderef_print_barcoded_entry( { fh_out => $fh_out,  barcodes => $barcode} );
 
        # Apply coderef to every FASTQ entry
        my $filename = filename_for("fastq_GCT TNC");
        process_fastq($filename, $print_barcoded_entry);
 
        my $expected = string_from("fastq_$barcode");
        is( $result, $expected, "FASTQ contains sequences starting with barcode(s): $barcode" );

        # Delete temp file
        unlink($filename);
    }
}


done_testing();


sub count_of_nucleotides {
    my $href = shift // return;             # If not defined, return immediately
    my $seq  = $href->{seq};
    my @nt   = split $EMPTY_STRING, $seq;
    my %count_of;
    $count_of{$_}++ for @nt;
    return \%count_of;
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
    die "'$filename' already exists." if -e $filename;

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
__[ fastq_GCT TNC ]__
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
__[ fastq_GCT ]__
@HWI-ST538:168:XXXXXXXXX:4:1101:1214:1873 1:Y:0:
GCTGATGNAGCAGCTCTNCAGGACNGACCTTAGNNNCAACAAGTTTGAGNNGGATGTNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+
<#05=@?#2@@@@@??@#3@>@@@#1:=???<?###00<=???=??==?###################################################
@HWI-ST538:168:XXXXXXXXX:4:1101:1414:1873 1:Y:0:
GCTGATGNAGCAGCTCTNCAGGACNGACCTTAGNNNCAACAAGTTTGAGNNGGATGTAGCTTCGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+
<#05=@?#2@@@@@??@#3@>@@@#1:=???<?###00<=???=??==?###################################################
__[ fastq_TNC ]__
@HWI-ST538:168:XXXXXXXXX:4:1101:1146:1888 1:Y:0:
TNCGTTTGCAGCCCGGGCAGCGTCCGGAGGATCGANCTGGTGGGCGGCGNNGTTGGGNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
+
<#0@-(:@@@@)@(((:=???/-<=???########################################################################
