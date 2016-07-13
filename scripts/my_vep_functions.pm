#!/usr/bin/env perl

package my_vep_functions;
require Exporter ;

use strict;
use warnings;

use my_warnings qw(dieq error_mess);

our @ISA = qw(Exporter) ;
our @EXPORT_OK = qw(
parse_vep_meta_line 
parse_vep_info
fill_vep_table
check_vep_allele
parse_vep_csq
vep_impact
vep_csq
);

sub parse_vep_meta_line {

    my $l = shift || "";

    dieq error_mess."unexpected VEP meta line: $l" unless $l =~ /Format: ([^"]+)">$/;

    my $vep_header = $1;
    my $vep_format = [split /\|/, $vep_header];

    return $vep_format;

}

sub parse_vep_info {

    my $vep_info = shift;
    my $vep_infos = [split /,/, $vep_info];
    return $vep_infos;
}

sub fill_vep_table {

    my ($vi,$vep_format) = @_;
    
    my @vep = split /\|/, $vi;
    my $vep_table = {};

    foreach my $i (0..$#vep) {

	my $what = $vep_format->[$i];
	$vep_table->{$what} = $vep[$i];
    }
    return $vep_table;
}

  
sub parse_vep_csq {

    my $c = shift;
    my $csqs = [split /&/, $c];

    return $csqs;
}

sub check_vep_allele {

    my ($ref,$my_alt,$vep_alt,$chr,$pos) = @_;

    my $is_good;

    if (length $my_alt == length $ref) {

	$is_good = 1 if $my_alt eq $vep_alt;

    } elsif (length $my_alt > length $ref) { # insertion
 	
	my $rest_alt_nt = substr $my_alt,1,length $my_alt;
	my $first_alt_nt = substr $my_alt,0,1;
	my $first_ref_nt = substr $ref,0,1;
	
	dieq "TYPE1: $first_alt_nt != $first_ref_nt" unless $first_ref_nt eq $first_alt_nt;
	
	$is_good = 1 if $vep_alt eq $rest_alt_nt or $vep_alt eq $my_alt;
	
    } elsif (length $ref > length $my_alt) { # deletion 
	
	my $first_alt_nt = substr $my_alt,0,1;
	my $first_ref_nt = substr $ref,0,1;
	
	dieq "TYPE2: $first_alt_nt != $first_ref_nt" unless $first_ref_nt eq $first_alt_nt;
	
	$is_good = 1 if $vep_alt eq "-" or $vep_alt eq $my_alt;
    }

    return $is_good;
}

sub vep_impact {


    # A subjective classification of the severity of the variant consequence. The four categories are:
    # for more information: 
    # http://www.ensembl.org/Help/Glossary?id=535
    # 
    my $vep_impact = {

	HIGH => "The variant is assumed to have high (disruptive) impact in the protein, probably causing protein truncation, loss of function or triggering nonsense mediated decay",
	MODERATE => "A non-disruptive variant that might change protein effectiveness",
	LOW => "Assumed to be mostly harmless or unlikely to change protein behaviour",
	MODIFIER => "Usually non-coding variants or variants affecting non-coding genes, where predictions are difficult or there is no evidence of impact"
    };

    return $vep_impact;
}

sub vep_csq {

    my $vep_csq = {
	
	transcript_ablation => ["A feature ablation whereby the deleted region includes a transcript feature","SO:0001893","Transcript ablation","HIGH"],
	splice_acceptor_variant => ["A splice variant that changes the 2 base region at the 3 prime end of an intron","SO:0001574","Splice acceptor variant","HIGH"],
	splice_donor_variant => ["A splice variant that changes the 2 base region at the 5 prime end of an intron","SO:0001575","Splice donor variant","HIGH"],
	stop_gained => ["A sequence variant whereby at least one base of a codon is changed, resulting in a premature stop codon, leading to a shortened transcript","SO:0001587","Stop gained","HIGH"],
	frameshift_variant => ["A sequence variant which causes a disruption of the translational reading frame, because the number of nucleotides inserted or deleted is not a multiple of three","SO:0001589","Frameshift variant","HIGH"],
	stop_lost => ["A sequence variant where at least one base of the terminator codon (stop) is changed, resulting in an elongated transcript","SO:0001578","Stop lost","HIGH"],
	start_lost => ["A codon variant that changes at least one base of the canonical start codon","SO:0002012","Start lost","HIGH"],
	transcript_amplification => ["A feature amplification of a region containing a transcript","SO:0001889","Transcript amplification","HIGH"],
	inframe_insertion=> ["An inframe non synonymous variant that inserts bases into in the coding sequence","SO:0001821","Inframe insertion","MODERATE"],
	inframe_deletion => ["An inframe non synonymous variant that deletes bases from the coding sequence","SO:0001822","Inframe deletion","MODERATE"],
	missense_variant => ["A sequence variant, that changes one or more bases, resulting in a different amino acid sequence but where the length is preserved","SO:0001583","Missense variant","MODERATE"],
	protein_altering_variant => ["A sequence_variant which is predicted to change the protein encoded in the coding sequence","SO:0001818","Protein altering variant","MODERATE"],
	splice_region_variant => ["A sequence variant in which a change has occurred within the region of the splice site, either within 1-3 bases of the exon or 3-8 bases of the intron","SO:0001630","Splice region variant","LOW"],
	incomplete_terminal_codon_variant => ["A sequence variant where at least one base of the final codon of an incompletely annotated transcript is changed","SO:0001626","Incomplete terminal codon variant","LOW"],
	stop_retained_variant => ["A sequence variant where at least one base in the terminator codon is changed, but the terminator remains","SO:0001567","Stop retained variant","LOW"],
	synonymous_variant => ["A sequence variant where there is no resulting change to the encoded amino acid","SO:0001819","Synonymous variant","LOW"],
	coding_sequence_variant => ["A sequence variant that changes the coding sequence","SO:0001580","Coding sequence variant","MODIFIER"],
	mature_miRNA_variant => ["A transcript variant located with the sequence of the mature miRNA","SO:0001620","Mature miRNA variant","MODIFIER"],
	"5_prime_UTR_variant" => ["A UTR variant of the 5 prime UTR","SO:0001623","5 prime UTR variant","MODIFIER"],
	"3_prime_UTR_variant" => ["A UTR variant of the 3 prime UTR","SO:0001624","3 prime UTR variant","MODIFIER"],
	non_coding_transcript_exon_variant => ["A sequence variant that changes non-coding exon sequence in a non-coding transcript","SO:0001792","Non coding transcript exon variant","MODIFIER"],
	intron_variant => ["A transcript variant occurring within an intron","SO:0001627","Intron variant","MODIFIER"],
	NMD_transcript_variant => ["A variant in a transcript that is the target of NMD","SO:0001621","NMD transcript variant","MODIFIER"],
	non_coding_transcript_variant => ["A transcript variant of a non coding RNA gene","SO:0001619","Non coding transcript variant","MODIFIER"],
	upstream_gene_variant => ["A sequence variant located 5 prime of a gene","SO:0001631","Upstream gene variant","MODIFIER"],
	downstream_gene_variant => ["A sequence variant located 3 prime of a gene","SO:0001632","Downstream gene variant","MODIFIER"],
	TFBS_ablation => ["A feature ablation whereby the deleted region includes a transcription factor binding site","SO:0001892","TFBS ablation","MODIFIER"],
	TFBS_amplification => ["A feature amplification of a region containing a transcription factor binding site","SO:0001892","TFBS amplification","MODIFIER"],
	TF_binding_site_variant => ["A sequence variant located within a transcription factor binding site","SO:0001782","TF binding site variant","MODIFIER"],
	regulatory_region_ablation => ["A feature ablation whereby the deleted region includes a regulatory region","SO:0001894","Regulatory region ablation","MODERATE"],
	regulatory_region_amplification => ["A feature amplification of a region containing a regulatory region","SO:0001891","Regulatory region amplification","MODIFIER"],
	feature_elongation => ["A sequence variant located within a regulatory region","SO:0001907","Feature elongation","MODIFIER"],
	regulatory_region_variant => ["A sequence variant located within a regulatory region","SO:0001566","Regulatory region variant","MODIFIER"],
	feature_truncation => ["A sequence variant that causes the reduction of a genomic feature, with regard to the reference sequence","SO:0001906","Feature truncation","MODIFIER"],
	intergenic_variant => ["A sequence variant located in the intergenic region, between genes","SO:0001628","Intergenic variant","MODIFIER"],
    };

    return $vep_csq;
}
