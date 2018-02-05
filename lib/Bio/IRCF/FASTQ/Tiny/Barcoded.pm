#!/bin/env perl
package Bio::IRCF::FASTQ::Tiny::Barcoded;
# ABSTRACT: Filter FASTQ file for reads that have a barcode and that have a minimum length (not counting the barcode) 

#=============================================================================
# STANDARD MODULES AND PRAGMAS
use 5.010;    # Require at least Perl version 5.10
use strict;   # Must declare all variables before using them
use warnings; # Emit helpful warnings
use autodie;  # Fatal exceptions for common unrecoverable errors (e.g. open)
use Bio::IRCF::FASTQ::Tiny qw( process_fastq coderef_print_entry);
use Carp qw( croak);

use IO::Compress::Gzip;

# Run as a command-line program if not used as a module
main(@ARGV) if !caller();

my $MIN_LENGTH;

sub main {

    # Get the name of the FASTQ file
    my $filename  = shift // die 'gzipped fastq file required';

    # Get the name of the barcode file
    my $barcode_file = shift // die 'barcode file required';

    $MIN_LENGTH    = shift // 64;

    my $basename = basename_for($filename);

    # Create a filehandle for the barcode file
    open(my $fh_barcodes, '<', $barcode_file);

    # Extract the barcodes
    my @barcodes = readline $fh_barcodes;
    chomp @barcodes;

    # Create a FASTQ file for barcoded reads, and one for unmatched reads
    my $fh_out       = IO::Compress::Gzip->new("$basename.barcode_filtered.fastq.gz");
    my $fh_unmatched = IO::Compress::Gzip->new("$basename.unmatched.fastq.gz");

    # Create coderef which prints to the barcoded FASTQ files
    my $print_by_barcode = __print_by_barcode( $fh_out, $fh_unmatched, @barcodes);

    process_fastq($filename, $print_by_barcode);

    return;
}

sub __print_by_barcode {
    my $fh_chosen       = shift;
    my $fh_unmatched = shift;
    my @barcodes     = @_;

    my $print_matched = coderef_print_entry($fh_chosen);

    my $matching_barcode = __matches_barcode(\@barcodes);

    my $print_unmatched = coderef_print_entry($fh_unmatched);

    return sub {
        my $href = shift;

        my $barcode = $matching_barcode->($href->{seq});

        if ( defined $barcode){
            $print_matched->($href);
        }else{
            $print_unmatched->($href);
        }
    };
}

sub _print_coderefs {
    my $fh_for_href = shift;
    my @barcodes    = keys %{ $fh_for_href };

    my %print_to_fh_for =
      map {
            ( $_ => coderef_print_entry( $fh_for_href->{$_} ) )
          } @barcodes;

    return \%print_to_fh_for;
}

sub __matches_barcode {
    my $barcodes_aref = shift;

    return sub {
        my $string = shift;

        for my $barcode ( @{ $barcodes_aref} )
        {
            # Return matching barcode if found
            if (index($string,$barcode) == 0 ) {
                my $length = length($string) - length($barcode);

                return if $length < $MIN_LENGTH;

                return $barcode;   
            }
        }

        # No barcode found
        return;
    };
}

sub basename_for 
{
    my $filename = shift;

    my $basename;
    if ( $filename =~ m{.*? ([^/]*) (?:[._]fastq)? (?:.txt|\.fastq|\.fq)?}xms )
    {
        $basename = $1; 
        return $basename;
    }

    # Can't seem to parse this one, so let's just use the original filename
    return $filename;
}

# COMMAND LINE
#=============================================================================


#-----------------------------------------------------------------------------

1;  #Modules must return a true value

=pod

=head1 NAME

Bio::IRCF::FASTQ::Tiny::Barcoded

=cut
