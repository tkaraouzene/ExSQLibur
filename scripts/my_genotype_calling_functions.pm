#!/usr/bin/env perl

package my_genotype_calling_functions;
require Exporter ;

use strict;
use warnings;

use my_warnings qw(dieq warnq warn_mess error_mess);
use my_allele_count_functions qw(parse_run_count);

use callGenotype_TK qw(callGeno);
use feature qw(say);

our @ISA = qw(Exporter) ;
our @EXPORT_OK = qw(
parse_geno_line
geno_header
call
skip_geno_header
check_geno
parse_genotypes
geno_code
) ;

sub skip_geno_header {

    my $geno_fh = shift;
    my $geno_info_lines;
    my $geno_header;

    while (1) {

	my $l = <$geno_fh>;
	chomp $l;

	dieq error_mess."unexpected genotype header line: $l" unless $l =~ /^#/;

	if ($l =~ /##/) {

	    $geno_info_lines .= "\n" if $geno_info_lines;
	    $geno_info_lines .= $l;

	} elsif ($l =~ /^#[^#]/) {

	    $geno_header = $l;
	    last ;

	}  else {

	    dieq error_mess."unexpected genotype header line:\n$l";
	}
    }
    
    dieq error_mess."no meta lines found found" unless $geno_info_lines;
    dieq error_mess."no vcf header found" unless $geno_header;
    
    return $geno_info_lines,$geno_header;
}


sub parse_geno_line {

    ##################
    # 
    # 0: chromosome (ex: 11)
    # 1: Position: variant position (ex: 209898)
    # 2: Reference allele
    # 3: Variation allele
    # 4: genotypes
    # 
    ##################

    my $l = shift;
    chomp $l;
    
    if (defined $l) {

	my @c = split /\t/,$l;
	my @r;
	
	dieq error_mess."unexpected nb of columns: $l" unless @c == 5;

	my ($chr,$pos,$ref,$alt,$g) = @c;
	
	dieq error_mess."unexpected ref allele: $ref: $l" unless $ref =~ /^[ATCGN]+$/i;
	dieq error_mess."unexpected alt allele: $alt: $l" unless $alt =~ /^[ATCGN]+$/i;
	dieq error_mess."unexpected chr: $chr" unless $chr =~ /^\d+|[XY]$/;
	dieq error_mess."unexpected position: $pos" unless $pos =~ /^\d+$/;
	dieq error_mess."unexpected genotypes: $g" unless $g =~ /^(\d||[\*abcdefghi])+$/;	

	if ($chr =~ /^d+$/) { 
	    dieq error_mess."unexpected chr number: $chr" if $chr < 1 || $chr > 22; 
	}

	push @r, $c[$_] foreach @_;

	(@r) ? 
	    (return @r) :
	    (return @c);
    }

    else {
	warnq warn_mess."no genotype line define";
	return -1;
    }
}

sub parse_genotypes {

    my $genotypes = shift;
    my $g = [split //,$genotypes];

    return $g;
}


sub geno_header {

    my ($runsList,$genoSettings) = @_;
    my ($mincov,$maxhomor,$lowgrey,$minhet,$maxhet,$highgrey,$minhomov) = @$genoSettings;
    my $list = join " ",@$runsList;
    my @geno_meta;

    push @geno_meta, "## mincov = ".$mincov;
    push @geno_meta, "## maxhomor = ".$maxhomor;
    push @geno_meta, "## lowgrey = ".$lowgrey;
    push @geno_meta, "## minhet = ".$minhet;
    push @geno_meta, "## maxhet = ".$maxhet;
    push @geno_meta, "## highgrey = ".$highgrey;
    push @geno_meta, "## minhomov = ".$minhomov;

    my $geno_meta = join "\n", @geno_meta;
    my $fields = join "\t", "#CHR","POS","REF","ALT",$list;
    my $geno_header = $geno_meta."\n".$fields;

    return $geno_header;
}

sub call {
    
    my ($geno_settings,$tot_cov,$var_counts) = @_;
    my $geno_code;
    
    if (defined $var_counts) {

        dieq error_mess."fix me: tot cov is undef" unless defined $tot_cov;

	##################
	# 
	# 0: run: run ID
	# 1: rp: nb of reference allele on forward strand 
	# 2: vp: nb of variant allele on forward strand
	# 3: rm: nb of reference allele on reverse strand
	# 4: vm: nb of variant allele on reverse strand
	#
	######################
	my ($rp,$vp,$rm,$vm) = parse_run_count $var_counts,1..4;
	my ($condition,$value) = callGeno $geno_settings,$tot_cov,$rp,$vp,$rm,$vm;
    
	$geno_code = &geno_code($condition,$value);

    } else { 
	    
	$geno_code = "*";
    }


    dieq error_mess."geno code should be defined" unless defined $geno_code;


    return $geno_code;
}


sub geno_code {

    my ($condition,$value) = @_;
    my $geno_code;

    dieq error_mess."Fix me: unexpected condition: $condition, should never be equal to 0" if $condition eq "0";
    
    if ($condition eq "NS") {

	dieq error_mess."unexpected value: $condition, $value" unless $value == 0;
	$geno_code = 0; 

    } elsif ($condition eq "DS") {

	if ($value eq "HR") { $geno_code = 1; }
	elsif ($value eq "HET") { $geno_code = 2; }
	elsif ($value eq "HV") { $geno_code = 3; }
	elsif ($value eq "NC") { $geno_code = 4; }
	elsif ($value eq "NCLGL") { $geno_code = 5; }
	elsif ($value eq "HVPC") { $geno_code = 6; }
	elsif ($value eq "PC") { $geno_code = 7; }
	elsif ($value eq "discW") { $geno_code = 8; }
	elsif ($value eq "discS") { $geno_code = 9; }
	else { 	dieq error_mess."unexpected genotype value: $condition, value: $value" unless $value == 0; }

    }  elsif ($condition eq "SS") {

	if ($value eq "HR") { $geno_code = "a"; }
	elsif ($value eq "HET") { $geno_code = "b"; }
	elsif ($value eq "HV") { $geno_code = "c"; }
	elsif ($value eq "LGL") { $geno_code = "d"; }
	elsif ($value eq "LGR") { $geno_code = "e"; }
	elsif ($value eq "HGL") { $geno_code = "f"; }
	elsif ($value eq "HGR") { $geno_code = "g"; }
	elsif ($value eq "HVPC") { $geno_code = "h"; }
	elsif ($value eq "PC") { $geno_code = "i"; }
	else { dieq error_mess."unexpected genotype value: $condition, value: $value"; }

    } else { dieq error_mess."geno_code: unexpected genotype condition: $condition"; }

    dieq error_mess."unexpected geno code: $geno_code" unless $geno_code =~ /^(\d||[abcdefghi])$/;	

    return $geno_code;
}


sub check_geno {

    my ($genotypes,$runs_list) = @_;
    my $nb_genotypes = @$genotypes;
    my $nb_runs = @$runs_list;

    dieq error_mess."runs_list and genotypes should contain the same number of element: $nb_runs != $nb_genotypes" unless @$runs_list == @$genotypes;

    return $nb_genotypes;
}
