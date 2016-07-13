#!/usr/bin/env perl

package my_vcf_functions;
require Exporter ;

use strict;
use warnings;

use my_warnings qw(dieq warnq warn_mess error_mess);


our @ISA = qw(Exporter) ;
our @EXPORT_OK = qw(

skip_vcf_meta 
parse_vcf_header
parse_vcf_line 
is_indel
parse_vcf_info
parse_alt_field
fill_others_table
make_vcf_header
) ;

sub skip_vcf_meta {

    my $in_vcf_fh = shift;
    my $vcf_meta_lines;
    my $vcf_header;
    my %needed;
    my @r;

    $needed{$_}->{search} = 1 foreach @_;

    while (1) {

	my $l = <$in_vcf_fh>;

	chomp $l;	

	dieq error_mess."unexpected metadata line: $l" unless $l =~ /^#/;

	if ($l =~ /##/) {

	    if (%needed) {
	    
		if  ($l =~ /##INFO=<ID=([^,]+)/) {

		    my $key = $1;
		    
		    if (defined $needed{$key}) {

			push @r, $l;
			$needed{$key}->{found} = 1;	
		    }
		}
	    }

	    $vcf_meta_lines .= "\n" if $vcf_meta_lines;
	    $vcf_meta_lines .= $l;

	} elsif ($l =~ /^#[^#]/) {
		
	    $vcf_header = $l;
	    last ;

	} else {

	    dieq error_mess."unexpected line:\n$l";
	}
    }

    dieq error_mess."no meta lines found found" unless $vcf_meta_lines;
    dieq error_mess."no vcf header found" unless $vcf_header;

    my $missing;

    foreach my $key (keys %needed) {
	$missing .= "no meta lines found for the id: $key\n" unless defined $needed{$key}->{found};
    }

    dieq error_mess.$missing if defined $missing;
    
    (@r) ?
	(return $vcf_meta_lines,$vcf_header,@r) :
	(return $vcf_meta_lines,$vcf_header);
}

sub parse_vcf_header {

    my $h = shift;

    $h =~ s/^#//;
    
    my @h = split /\t/, $h;

    dieq error_mess."unexpected nb of field: $h" unless @h >= 8;

    shift @h; # chr
    shift @h; # pos
    shift @h; # id
    shift @h; # ref
    shift @h; # alt
    shift @h; # qual
    shift @h; # filter
    shift @h; # info
    shift @h; # format

    return \@h;
}

sub parse_vcf_line {

    ##################
    # 
    # 0: chromosome (ex: 11)
    # 1: Position: variant position (ex: 209898)
    # 2: variant ID
    # 3: Reference allele
    # 4: Variation allele
    # 5: Quality
    # 6: Filter 
    # 7: Info
    # 8: Format
    # 9: Others
    # 
    ##################

    my $l = shift;
    chomp $l;

    if ($l) {

	my @c = split /\t/, $l;
	my @r;

	dieq error_mess."vcf line should contain at least 8 column: $_" unless @c >= 8;

	my ($chr,$pos,$rs,$ref,$alts,$qual,$filter,$info,$format,$others) = @c;

	$chr =~ s/^chr//;

	dieq error_mess."unexpected chr: $chr" unless $chr =~ /^\d+$|^[XY]$|^MT$/;
	dieq error_mess."unexpected position: $pos" unless $pos =~ /^\d+$/;
	dieq error_mess."unexpected res: $ref" unless $ref =~ /^[ATCGN]+$/i;
	dieq error_mess."unexpected alt: $alts" unless $alts =~ /^[ATCGN,]+$/i;

	if ($chr =~ /^d+$/) { 
	    dieq error_mess."unexpected chr number: $chr" if $chr < 1 || $chr > 22; 
	}

	push @r, $c[$_] foreach @_;

	# return fields needed (or all fields if nothing is mentionned 
	(@r) ? 
	    (return @r) :
	    (return @c);
    }

    else {
	warnq warn_mess."no vcf line define";
	return -1;
    }
}

sub parse_alt_field {

    my ($ref,$alts) = @_;
    my $all_alts = [split /,/, $alts];

    foreach my $alt (@$all_alts) {
    
	    if (length $ref == length $alt) {
		
		my $f_ref = substr $ref, 0,1;
		my $f_alt = substr $alt, 0,1;
		my $r_ref = substr $ref, 1;
		my $r_alt = substr $alt, 1;
		
		dieq error_mess."should be different: $f_ref :: $f_alt\n$ref :: $alt" if $f_ref eq $f_alt;
		dieq error_mess."should be different 2: $ref :: $alt" unless $r_ref eq $r_alt;
    	}
    }
    return $all_alts;
}

sub is_indel {

    my ($ref,$alt) = @_;
    my $is_indel = 0;
    
    dieq error_mess."unexpected res: $ref" unless $ref =~ /^[ATCGN]+$/i;
    dieq error_mess."unexpected alt: $alt" unless $alt =~ /^[ATCGN]+$/i;

    $is_indel = 1 unless length $ref == length $alt;

    return $is_indel;
}


sub parse_vcf_info {

    my $info = shift;
    my @infos = split /;/, $info;
    my $info_table = {};
	    
    foreach my $i (@infos) {

	unless ($i eq "") { # when ";;" in info 
	    
	    if ($i =~ /^(.+)=(.+)$/) {
		
		dieq error_mess."" if defined $info_table->{$1};


		$info_table->{$1} = $2;
		
	    } else { 
		
		dieq error_mess."" if defined $info_table->{$i};
		$info_table->{$i} = ""; }  
	}
    }	   
    return $info_table;
}
  

sub fill_others_table {

    my ($others,$format,$sample_list) = @_;
    my $others_table = {};

    my @o = split /:/, $others;
    my @f = split /:/, $format;

    dieq error_mess."format and other fields should contain the same nb of elements: $format :: $others" unless @f == @o;

    foreach my $sample (@$sample_list) {

	foreach my $i (0..$#o) {

	    my $f = $f[$i];
	    my $o = $o[$i];
	    $others_table->{$sample}->{$f} = $o;
	}
    }
    return $others_table;
}

sub make_vcf_header {
    
    my ($format,$runs_list) = @_;
    my $vcf_header = "#".join "\t", "CHROM","POS","ID","REF","ALT","QUAL","FILTER","INFO";
    
    (@_) ? 
	(return join "\t", $vcf_header, $format, @$runs_list) :
	(return $vcf_header);
}
