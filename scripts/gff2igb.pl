#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;


my $infile = undef;
my $outfile = "genome.gff";


#==========================================================================
#read comand line arguments

read_command_line();


#print Data::Dumper->Dump([$infile, $outfile ], [qw(*infile *outfile )]);
#exit;



#==========================================================================
#Read input genome in General Feature Format (gff)


my @header = ();
my @data   = ();


#open input file in either gzip or text format
my $fh = undef;
if ($infile =~ /.+\.gz/) {
  open ($fh, "-|", "zcat $infile") || die $!;
}
else {
  open ($fh, "<", $infile) || die $!;
}


LINE:while (<$fh>) {

  chomp;

  push(@header, $_) if (/^#/);

  unless (/^#/) {
    my @cols = split (/\t/, $_);

    #Ignore the following sequence features
    next LINE if ($cols[2] =~ /RNase_P_RNA/ || /gene_biotype=RNase_P_RNA/);
    next LINE if ($cols[2] =~ /SRP_RNA/ || /gene_biotype=SRP_RNA/);
    next LINE if ($cols[2] =~ /antisense_RNA/ || /gene_biotype=antisense_RNA/);
    next LINE if ($cols[2] =~ /exon/);
    next LINE if ($cols[2] =~ /mobile_genetic_element/);
    next LINE if ($cols[2] =~ /ncRNA/ || /gene_biotype=ncRNA/);
    next LINE if ($cols[2] =~ /origin_of_replication/);
    next LINE if ($cols[2] =~ /region/ || /repeat_region/);
    next LINE if ($cols[2] =~ /sequence_feature/);
    next LINE if ($cols[2] =~ /repeat_region/);

    push (@data, [$cols[3], $cols[4], $cols[2], $_]);
  }
}
close $fh;


#print Data::Dumper->Dump([\@data ], [qw(*data )]);
#exit;



#==========================================================================
#Assign refseq accessions to gene names so the Integrated Genome Browser
#displays the accession instead of locus_tag.

foreach my $i (0 .. $#data - 1) {

  my $ref = $data[$i];
  my $cmp = $data[$i + 1];


  if ($ref->[2] eq "gene") {
    if ($cmp->[2] eq "CDS") {

      if ($ref->[0] == $cmp->[0] && $ref->[1] == $cmp->[1]) {

	#Replace the gene names with the refseq accession
	substitute_accession($ref, $cmp);
      }
    }
  }
  elsif ($ref->[2] eq "CDS") {
    if ($cmp->[2] eq "gene") {

      if ($ref->[0] == $cmp->[0] && $ref->[1] == $cmp->[1]) {

	#Replace the gene names with the refseq accession
	substitute_accession($cmp, $ref);
      }
    }
  }
}


#==========================================================================
#Save reformatted GFF file

open (my $outh, ">", $outfile) || die $!;
print $outh join("\n",  @header), "\n";
foreach my $res (@data) {
  print $outh $res->[3], "\n";
}
close $outh;


###########################################################################
##                                                                       ##
##                        Subroutine definitions                         ##
##                                                                       ##
###########################################################################

#==========================================================================
#Replace the name of the gene with the refseq accession.

sub substitute_accession {

  my ($r, $c) = @_;

#  print "Before:\n", Data::Dumper->Dump([$r, $c], [qw(*ref *cmp )]);
#  <STDIN>;

  my $refseq = undef;
  if ($c->[3] =~ /protein_id=([a-zA-Z0-9\._]+)/) {
    $refseq = $1;

    $r->[3] =~ s/Name=[a-zA-Z0-9\._]+/Name=$refseq/;
    $r->[3] =~ s/gene=[a-zA-Z0-9\._]+/gene=$refseq/;
  }

#  print "After:\n", Data::Dumper->Dump([$data[$1], $data[$i+1] ], [qw(*ref *cmp )]);
#  <STDIN>;
}



#===========================================================================
#Read command line and print help


sub read_command_line {

    print_help() unless (@ARGV);

    my $status = GetOptions(
	"g|in-gff-file=s"    => \&read_infile,
	"o|out-gff-file=s"   => \&read_outfile,
	"h|help"             => sub { print_help(); },
	"<>"                 => sub { die "Error: Unknown argument: $_[0]\n"; });
    exit unless ($status);
}



sub read_infile {
    my ($opt, $value) = @_;

    unless (-f $value) {
      die "Error: input gff file does not exist -> $value";
    }

    $infile = $value;
}




sub read_outfile {
    my ($opt, $value) = @_;

    $outfile = $value;
}





sub print_help {

    my $help = <<'HELP';

This script reads a file in General Feature Format (gff) as generated by genbank
and replaces the name of a gene with the RefSeq accession. This has the purpose of
allowing the Integrated Genome Browser to be able to display the refseq and allow
searches using accessions as queries.

-g, --in-gff-file {path}
   Input file in gff format as generated by GenBank. File can be in plain text or
   compressed with gzip. (Mandatory)

-o, --out-gff-file {path}
   Output file in GFF format that will be fed to the Integrated Genome Browser
   (Default: genome.gff)

-h, --help
   Display this help. Also displayed if script is run without arguments.

HELP

    print $help;
    exit;
}

