#!/usr/bin/env perl

package my_snph_functions;
require Exporter ;

use strict;
use warnings;

use my_warnings qw(dieq error_mess);


our @ISA = qw(Exporter) ;
our @EXPORT_OK = qw(

skip_snph_header
find_snph_file
parse_snph_line
parse_snph_variant
snph_indel_position_recalibration
) ;

sub skip_snph_header {

     my $skip;
    $skip = 1 if $_ =~ /^\#Target/; 
    
    return $skip; 
}

sub find_snph_file {

    my ($snph_dir,$chr) = @_;
    my $snph_file;
    
    $snph_dir .= "/".$chr;

    opendir my $snph_dh, $snph_dir || dieq error_mess."Can't opendir $snph_dir: $!";
    
    while (my $f = readdir $snph_dh) {
	
	next unless $f =~ /\.snp\.sorted$/;
	$snph_file = $snph_dir."/".$f;
	last;
    }

    closedir $snph_dh;
    
    dieq error_mess."no snph_file found in $snph_dir" unless $snph_file;

    return $snph_file;
}

sub parse_snph_line {

    ##################
    # 
    # 0: Target: chromosome (ex: 11)
    # 1: Position: variant position (ex: 209898)
    # 2: Type: variant (ex: G>A, DelCCC)
    # 3: Reference: context of Ref sequence (ex: GAAccccccACCCAC)
    # 4: Variation: context of Var sequence (ex: GAAccc---ACCCAC)
    # 5: Run: run ID (ex: Ghs89)
    # 6: Dose: 
    # 7: %%: percentage of read carrying ref allele at this position
    # 8: Cover: nb total of read overlapping this position
    # 9: V=: nb of read carrying the variant allele a this position
    # 10: R=: nb of read carrying the reference allele a this position
    # 11: V+: nb of read carrying the variant allele a this position sequenced on forward strand
    # 12: R+: nb of read carrying the reference allele a this position sequenced on forward strand
    # 13: V-: nb of read carrying the variant allele a this position sequenced on reverse strand
    # 14: R-: nb of read carrying the reference allele a this position sequenced on reverse strand
    # 15: N+: 
    # 16: N-: 
    # 17: Amb: 
    # 18: Type: 
    # 19: Chi2: 
    # 20: N_rich: 
    # 21: Dose+: 
    # 22: Dose-: 
    #
    ######################

    chomp(my $l = shift);
    my @c = split /\t/,$l;
    my @r;

    my ($target,$pos,$type1,$ref,$var,$run,$dose,$percent,$tot_cov,$var_cov,
	$ref_cov,$vp,$rp,$vm,$rm,$np,$nm,$amb,$type2,$chi2,$n_rich,
	$dose_p,$dose_m) = @c;
    
    dieq error_mess."total coverage cannot be negative: $tot_cov" unless $tot_cov >= 0;
    dieq error_mess."total coverage should be >= to ref_cov + var_cov: $tot_cov < $ref_cov + $var_cov" unless $tot_cov >= $ref_cov + $var_cov;
    dieq error_mess."unexpected coverage value for ref cov: $ref_cov != $rp + $rm" unless $ref_cov == $rp + $rm;
    dieq error_mess."unexpected coverage value for var cov: $var_cov != $vp + $vm" unless $var_cov == $vp + $vm;
    dieq error_mess."total var_cov + ref_cov cannot be negative: $var_cov + $ref_cov < 0" unless $var_cov + $ref_cov >= 0; 

    push @r, $c[$_] foreach @_;
    
    # return fields needed (or all fields if nothing is mentionned 
    (@r) ? 
	(return @r) :
	(return @c);
}

sub parse_snph_variant {

    my $variant = shift;
    my $ref;
    my $alt;
    my $is_indel;

    if ($variant =~ /^([ATCG])>([ATCG])$/) { 
	
	($ref,$alt) = ($1,$2); 

	dieq error_mess."ref and alt should be different: $ref eq $alt" if $ref eq $alt;


    } elsif ($variant =~ /^(Ins)([ATCG]+)$/) {

	$is_indel = $1;
	$alt = $2;
	
    } elsif ($variant =~ /^(Del)([ATCG]+)$/) {
	
	$is_indel = $1;
	$ref = $2;

    } else { 

	dieq error_mess."unexpected type of variant: $variant"; 
    }

    return $ref,$alt,$is_indel;
}

sub snph_indel_position_recalibration {

    my ($ref,$alt,$pos,$chr,$variant,$seq_ref,$seq_alt,$is_indel,$convert_pos_table) = @_;
    my $var = join ":", $chr,$pos,$variant;
    
    unless (defined $convert_pos_table->{$var}) {

	$$pos--; # to harmonize SNPH variant position with vcf variant position

	if ($is_indel eq "Ins") {

	    my $l = length $$alt; # length of the insertion
	    my $o = 6 - $l;

	    dieq error_mess."fix me: $is_indel($l): unexpected seq_ref: $seq_ref. Comment the first methode and uncomment the alternative methode" unless $seq_ref =~ /^[NATCGnatcg]{6}-{$l}[NATCG]{6}$/;
	    dieq error_mess."At this point Alt allele should be defined" unless defined $$alt;
	    dieq error_mess."At this point Ref allele should not be defined" unless !defined $$ref;

	    ##### FIRST METHODE #####
	    # only work if the alt pos is always the 7th character of $seqRef
	    # this seems to be true but ...
	    #
	    $$ref = uc(substr $seq_ref, 5,1);
	    $$alt = $$ref.$$alt;	 
	    
	    ##### ALTERNATIVE METHODE #####
	    # should be always true but slower than the first methode
	    # I have tested the both methods to compare results,
	    # as expected there are no differences (03/04/2014)
	    
	    # $alt = $1;	
	    # my $prev_ref;
	    
	    # foreach my $i (0..(length($seqRef)-1)){
	    #     my $current_ref = substr($seqRef,$i,1);
	    #     last if $current_ref eq "-";

	    #     $prev_ref = $current_ref;
	    # }

	    # $ref = uc($prev_ref);
	    # $alt = $ref.$alt;
	    
	} elsif($is_indel eq "Del") {

	    my $l = length $$ref; # length of the insertion
	    dieq error_mess."fix me: unexpected seq_alt = $seq_alt. Comment the first methode and uncomment the alternative methode" unless $seq_alt =~ /^[natcgNATCG]{6}-{$l}[NATCGnatcg]{6}$/;
	    dieq error_mess."At this point Alt allele should not be defined" unless !defined $$alt;
	    dieq error_mess."At this point Ref allele should be defined" unless defined $$ref;	
	    
	    ##### FIRST METHODE #####
	    # only work if the alt pos is always the 7th character of $seqRef
	    # this seems to be true but ...
	    #

	    $$alt = uc(substr $seq_alt,5,1);
	    $$ref = $$alt.$$ref;
	    
	    ##### ALTERNATIVE METHODE #####
	    # should be always true but slower than the first methode
	    # I have tested the both methods to compare results,
	    # as expected there are no differences (03/04/2014)
	    
	    # $ref = $1;
	    # my $prev_alt;
	    # foreach my $i (0..(length($seqAlt)-1)){
	    #     my $current_alt = substr($seqAlt,$i,1);
	    #     last if $current_alt eq "-";
	    #     $prev_alt = $current_alt;
	    # }
	    # $alt = uc($prev_alt);
	    # $ref = $alt.$ref;	
	} else { 
	    
	    dieq error_mess."unexpected type of variation: $is_indel"; 
	}
	
	$convert_pos_table->{$var} = [$$pos,$$ref,$$alt];
    
    } else {

	($$pos,$$ref,$$alt) = @{$convert_pos_table->{$var}};
    }

    return;
}
