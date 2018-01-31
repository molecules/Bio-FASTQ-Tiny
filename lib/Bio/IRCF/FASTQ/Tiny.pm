package Bio::IRCF::FASTQ::Tiny;
# ABSTRACT: FASTQ iterator designed to be much faster and much more flexible than using BioPerl

#=============================================================================
# STANDARD MODULES AND PRAGMAS
use v5.10;    # Require at least Perl version 5.10, thus enabling "//" and "say"
use strict;   # Must declare all variables before using them
use warnings; # Emit helpful warnings
use autodie;  # Fatal exceptions for common unrecoverable errors (e.g. open on nonexistent file)
use Carp qw(croak);
use IO::Uncompress::Gunzip;
use IO::Compress::Gzip qw($GzipError);
#=============================================================================

#=============================================================================
# Exporter settings
use base qw( Exporter );

our @EXPORT_OK = qw( iterator
                     process_fastq
                     to_fasta
                     coderef_alter_qual_scores_insitu
                     coderef_print_altered_quality
                     coderef_print_barcoded_entry
                     coderef_print_entry
                     open_input
                     open_output
                     );
#=============================================================================

my $SUCCESS = 1;

# Create FASTQ iterator
sub iterator {
    my $filename = shift // croak 'file name required';
    my $coderef  = shift // sub { shift() };            # Default returns hashref of FASTQ entry

    my $fh = open_input($filename);

    # create a line-by-line iterator for the file
    my $next_chomped_line = _coderef_next_chomped_line($fh);

    return sub {
        my $header   = _remove_first_char($next_chomped_line->()) // return; # Return if no more lines
        my $seq      =  $next_chomped_line->();
        my $q_header = _remove_first_char($next_chomped_line->());
        my $qual     = $next_chomped_line->();

        # Return the result of the codref acting on the current FASTQ entry
        return $coderef->(
            {
                header   => $header,
                seq      => $seq,
                q_header => $q_header,
                qual     => $qual,
            }
        );
    };
}

sub process_fastq {
    my $filename = shift // croak 'file name required';
    my $coderef  = shift // croak 'no codereference supplied';

    my $iterator = iterator($filename, $coderef);

    # Apply coderef to each FASTQ entry
    while(1){ last if ! defined $iterator->(); }

    return $SUCCESS;
}

sub _coderef_next_chomped_line {
    my $fh = shift // croak 'filehandle required';

    # Return an iterator that gives the next line (chomped) from the file
    return sub {

        # Read the next line from the file (or return if end of file reached)
        my $next_line = readline $fh // return;

        # Remove the newline character from it
        chomp $next_line;

        return $next_line;
    };
}

sub _remove_first_char {
    my $string = shift // return; # Don't modify something that is undefined
    return substr($string,1);
}

sub coderef_print_barcoded_entry {
    my $fh_out          = shift // croak 'Filehandle required';
    my $barcodes_string = shift // croak 'Barcodes string required';

    my $matches     = _coderef_matches_a_barcode($barcodes_string);
    my $print_entry = coderef_print_entry($fh_out);

    return sub {
        my $fastq_record = shift // return;    # If not defined, return immediately
        my $seq          = $fastq_record->{seq} // croak 'Sequence required';

        $print_entry->($fastq_record) if $matches->($seq);

        return $SUCCESS;
    };
}

sub _coderef_matches_a_barcode {
    my $barcodes_string = shift // croak 'Internal: barcodes string required';

    # Parse out space-delimited barcodes
    my @barcodes      = split /\s+/, $barcodes_string;

    return _coderef_matches_barcode_LTM( @barcodes);
}

sub _coderef_matches_barcode_LTM
{
    my @barcodes = @_;

    # longest-token-matching logic is necessary to distinguish some short
    # barcodes from longer ones, for example for lane 3 from flowcell C12BWACXX:
    #       AGGC     is the barcode for Z029E1001
    #       AGGCTAGA is the barcode for Z030E1028
    my @barcodes_longest_first = barcodes_sorted_longest_first( @barcodes );

    return sub {
        my $string = shift;

        for my $barcode ( @barcodes_longest_first )
        {
            # Return matching barcode if found
            return $barcode if ( index($string,$barcode) == 0);
        }

        # No barcode found
        return;
    };
}

sub barcodes_sorted_longest_first
{
    my @barcodes = @_;

    # $b before $a to get longest-first sorting
    return sort { length $b <=> length $a } @barcodes;
}

sub coderef_print_entry {
    my $fh = shift // croak 'Filehandle required';

    return sub {
        my $fastq_record = shift // croak 'sequence hash ref required';
        say {$fh} '@'. $fastq_record->{header};
        say {$fh}      $fastq_record->{seq};
        say {$fh} '+'. $fastq_record->{q_header};
        say {$fh}      $fastq_record->{qual};
        return $SUCCESS;
    };
}

sub coderef_alter_qual_scores_insitu {
    my $change_in_score = shift;

    return sub {
        my $fastq_record = shift // return;
        my @quals        = map {$_ + $change_in_score} unpack("c*", $fastq_record->{qual});

        $fastq_record->{qual} = pack("c*", @quals);
        return $fastq_record;
    };
}

sub coderef_print_altered_quality {
    my $fh_out = shift // croak 'fh_out required';
    my $addend = shift // croak 'addend required';

    my $print_entry    = coderef_print_entry($fh_out);
    my $change_quality = coderef_alter_qual_scores_insitu($addend);

    return sub {
        my $entry_href = shift // return;
        $change_quality->($entry_href);
        $print_entry->($entry_href);
        return $SUCCESS;
    };
}

sub to_fasta {
    my $fh_in  = shift // croak 'fh_in required';
    my $fh_out = shift // croak 'fh_out required';
    my $make_fasta_coderef = sub {
        my $entry_href = shift // return; # Explicit return for undefined value

        say {$fh_out} '>' . $entry_href->{header};
        say {$fh_out} $entry_href->{seq}         ;
        return $SUCCESS; # Must return true value
    };
    process_fastq($fh_in, $make_fasta_coderef);
    return;
}

# Open file for reading (as gzipped compressed if name ends in '.gz')
sub open_input {
    my $filename = shift;

    # Return decompressing filehandle if applicable
    return IO::Uncompress::Gunzip->new($filename, MultiStream => 1) if $filename =~ /\.gz$/xms;

    # Return normal "reading" filehandle
    open(my $fh, '<', $filename);
    return $fh;
}

# Open writable file (as gzipped compressed if name ends in '.gz')
sub open_output {
    my $filename = shift;

    if ($filename =~ /\.gz$/xms ) {
        my $fh = IO::Compress::Gzip->new($filename)
            or die "IO::Compress::Gzip failed: $GzipError\n";
        return $fh;
    }

    # Return normal "writable" filehandle
    open(my $fh, '>', $filename);
    return $fh;
}

#-----------------------------------------------------------------------------

1;  #Modules must return a true value
