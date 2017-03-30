Consider this Beta until it is officially released on CPAN. I want to solicit
community feedback before freezing the API.

# NAME

Bio::IRCF::FASTQ::Tiny

# VERSION

version 0.013

# SYNOPSIS

    use v5.10;
    use strict;
    use warnings;
    use autodie;

    use Bio::IRCF::FASTQ::Tiny qw( process_fastq );

    my $fastq_filename = shift;

    open(my $fh_fastq, '<', $fastq_filename);

    my $make_fasta_coderef = sub {
        my $entry_href = shift // return; # Explicit return for undefined value

        say '>' . $entry_href->{header};
        say $entry_href->{seq}         ;
        return 1; # Must return true value
    };

    process_fastq($fh_fastq, $make_fasta_coderef);

Another example. This one keeps track of each sequence and how many times it
occurs in a FASTQ file.

    use v5.10;
    use strict;
    use warnings;
    use autodie;

    use Bio::IRCF::FASTQ::Tiny qw( iterator );

    my $fastq_filename = shift;

    my $get_simple_entry = sub { return shift(); };

    my $fastq_it = iterator($fastq_filename, $get_simple_entry);

    my %count_of;

    while(my $entry_href = $fastq_it->() ){

        my $sequence = $entry_href->{seq};

        $count_of{ $sequence }++;
    }

    # Print out list of sequences and how many times each occurred
    for my $sequence ( sort keys %count_of){
       say $sequence, "\t", $count_of{$sequence};
    }

# DESCRIPTION

# SUBROUTINES/METHODS

## iterator()

        positional parameters:
            file name
                This is the name of a FASTQ file.

            coderef (optional)

                For each iteration, this coderef will be passed a hashref
                containing the keys 'header','seq','q_header', and 'qual',
                which refer to strings containing the header, sequence,
                quality header, and quality scores of a FASTQ entry,
                respectively. The strings for the header and quality header
                are stripped of their first character (i.e. '@' and '+',
                respectively).

                If no coderef is specified, this will simply return the
                hashref described above.

    Returns an iterator which applies the coderef to one FASTQ entry at a
    time, returning the result.

## process\_fastq()

    Takes the same arguments as iterator. However, instead of returning
    an iterator, it builds one internally and then exhaustively applies it to
    every entry in the FASTQ file.

## coderef\_print\_altered\_quality

    positional parameters:
        filehandle
            Output filehandle to which the altered FASTQ file will be written.

        integer
            Value added to the ASCII value of each quality character. For
            example, if this is -31, then a score of 'B' becomes '#', changing
            from an "old Illumina" encoding to the Sanger encoding.

    Returns a coderef compatible with C<process_fastq> or C<iterator>.

## coderef\_print\_barcoded\_entry

    positional parameters:

        hashref with the following keys

            fh_out  Filehandle to print to.
            barcodes  String containing barcodes separated by whitespace.

    Returns a coderef compatible with C<process_fastq> or C<iterator>.

## coderef\_print\_entry

    Returns a coderef compatible with C<process_fastq> or C<iterator>.

# RATIONALE

    Speed and flexibility. To change quality score formats, for example, this
    is over 10x faster than using BioPerl.

# DIAGNOSTICS

# CONFIGURATION AND ENVIRONMENT

    None special, besides those described in DEPENDENCIES.

# DEPENDENCIES

    Perl 5.10 or later.

# INCOMPATIBILITIES

    None that the author is aware of.

# BUGS AND LIMITATIONS

     There are no known bugs in this module.

     Please report problems to molecules at cpan.org.

     Patches are welcome.

# SEE ALSO

# ACKNOWLEDGEMENTS
