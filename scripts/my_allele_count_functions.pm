#!/usr/bin/env perl

package my_allele_count_functions;
require Exporter ;

use strict;
use warnings;

use my_warnings qw(dieq error_mess);
use my_file_manager qw(openIN openOUT);
use feature qw(say);

our @ISA = qw(Exporter) ;
our @EXPORT_OK = qw(

parse_allele_count_line
parse_run_count
build_pos_cov_table
) ;


sub parse_allele_count_line {

    ##################
    # 
    # 0: chromosome number (ex: 11)
    # 1: Position: variant position (ex: 209898)
    # 2: Reference allele
    # 3: Altered allele
    # 4: Allele count:
    #    - Format: Run1:Ref+:Var+:Ref-:Var-,...RunN:Ref+:Var+:Ref-:Var-
    #
    ######################
    
    my $l = shift;
    chomp $l;
    my @c = split /\t/, $l;

    dieq error_mess."unexpected nb of column in allele count line: $l" unless @c == 5;

    my @r;
    
    my ($chr,$pos,$ref,$alt,$counts) = @_;

    push @r, $c[$_] foreach @_;
    
    # return fields needed (or all fields if nothing is mentionned 
    (@r) ? 
	(return @r) :
	(return @c);
}

sub parse_run_count {

    ##################
    # 
    # 0: run: run ID
    # 1: rf: nb of reference allele on forward strand 
    # 2: vf: nb of variant allele on forward strand
    # 3: rr: nb of reference allele on reverse strand
    # 4: vr: nb of variant allele on reverse strand
    #
    ######################
    my $rc = shift;
    my @r;

    dieq error_mess."unexpected type of run_count : $rc" unless $rc =~ /^(Ghs\d+):(\d+):(\d+):(\d+):(\d+)$/;
    my @rc = ($1,$2,$3,$4,$5);

    push @r,$rc[$_] foreach @_;

    # return fields needed (or all fields if nothing is mentionned 
    (@r) ? 
	(return @r) :
	(return @rc);
}



sub build_pos_cov_table {
    
    my $allele_count_file = shift;
    my $ac_fh = openIN $allele_count_file;
    my $pos_cov_table = {};

    while (<$ac_fh>) {

	next if $_ =~ /^#/;
	
	##################
	# 
	# 0: chromosome number (ex: 11)
	# 1: Position: variant position (ex: 209898)
	# 2: Reference allele
	# 3: Altered allele
	# 4: Allele count:
	#    - Format: Run1:Ref+:Var+:Ref-:Var-,...RunN:Ref+:Var+:Ref-:Var-
	#
	######################

	my ($chr,$pos,$ref,$alt,$counts) = parse_allele_count_line $_;

	my @all_counts = split /,/, $counts;

	foreach my $run_count (@all_counts) {

	    ##################
	    # 
	    # 0: run: run ID
	    # 1: rf: nb of reference allele on forward strand 
	    # 2: vf: nb of variant allele on forward strand
	    # 3: rr: nb of reference allele on reverse strand
	    # 4: vr: nb of variant allele on reverse strand
	    #
	    ######################
	    my ($run,$rf,$vf,$rr,$vr) = parse_run_count $run_count;

	    (defined $pos_cov_table->{$chr}->{$pos}->{$run}) ? 
		($pos_cov_table->{$chr}->{$pos}->{$run}->{tot_cov} += $vf + $vr) : 
		($pos_cov_table->{$chr}->{$pos}->{$run}->{tot_cov} = $rf + $vf + $rr + $vr);
	    
	    $pos_cov_table->{$chr}->{$pos}->{$run}->{count}->{$ref.":".$alt} = $run_count;

	    dieq error_mess."tot cov should be >= 0: $rf + $vf + $rr + $vr = $pos_cov_table->{$chr}->{$pos}->{$run}->{tot_cov}" unless $pos_cov_table->{$chr}->{$pos}->{$run}->{tot_cov} >= 0;
	}
    }

    close $ac_fh;

    return $pos_cov_table;
}
