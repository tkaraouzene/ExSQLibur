#!/usr/bin/perl


# Make a genotype call, given mainly R+ V+ R- V- counts.
# See the comments at the top of callGeno function, in particular
# the return values and their meaning.
#
# UPDATE 06/04/2014
# For some positions a given run can have several lines corresponding
# to different SNV types (eg A>C and A>T).
# Fixing callGeno to take an additional parameter $totalCov, eg taken
# from the "Cover" column in MAGIC files: this is the sum of 
# quality-adjusted read counts at this position in this run.
# We use this to decide if we can make a clear call from this line,
# or if we don't make a call, or if we make a dubious/partial call.
# See below for details (search for covRat).
# 
# TODO: the strand-specific genotype calling parameters, which define
# the callzones and greyzones, are defined locally in callGenoStrand.
# That's where you must change them if necessary... But if this
# is really needed, it would be better to pass these parameters
# as an argument to callGeno and callGenoStrand .

package callGenotype_TK;
require Exporter;
@ISA = qw(Exporter) ;
@EXPORT = qw(callGeno);


use strict;
use warnings;
use my_warnings qw(dieq printq warnq warn_mess error_mess info_mess);

# callGeno: make a genotype call.
# Takes as args:
# $totalCov: total (quality-adjusted) number of reads that align
# at this position from this run;
# $rf,$vf,$rr,$vr: the number of Ref/Variant reads on the Plus/Minus strand;
# $minCov: the minimum strand coverage to make a call on a strand.
# Returns an array of strings ($s,$v):
# 1. $s among "NS","SS","DS","0": NoStrand (both below $minCov, or $covRat<$covRatLow), 
# SingleStrand, DoubleStrand (both strands above $minCov), or "0" if an error occurred;
# 2. if $s=="NS" or $s=="0", $v="0"
#    elsif $s=="DS" $v one of "HR","HET","HV","discW","discS","NC","NCLGL","HVPC","PC";
#    elsif $s=="SS" $v one of "HR","HET","HV","LGL","LGR","HGL","HGR","HVPC","PC".
# The $v values mean:
#    HR==homoref, HET==hetero, HV==homovar calls (strand-concordant if $s==DS);
#    discW and discS: Weakly or Strongly discordant calls on the two strands (see
#         the "stranding matters" paper for definitions);
#    NC==NoCall (but not NCLGL), only valid when $s==DS (see paper for def of NoCall zone);
#    NCLGL==NoCall in the LGL-LGL zone, I need this separately for counting...
#    HVPC==homovar with partial coverage ($covRat between $covRatLow and $covRatHigh);
#    PC==partial coverage and not homovar, these cannot be called but we may want to
#        flag or count them in the calling code;
#    LGL==lowgrey_left, LGR==lowgrey_right, HGL==highgrey_left, HGR==highgrey_right:
#         only for SS calls, specifices which half-greyzone we are in.
#
# We calculate $covRat = ($rf + $rr + $vf + $vr) / $totalCov, and use
# $covRatLow and $covRatHigh (hard-coded) as cutoffs to implement our strategy to deal
# with the "multiple lines for single position and run" problem:
# if $covRat < $covRatLow, return ("NS", "0");
# elsif $covRat > $covRatHigh, return whatever call was made;
# else
#    if $v was "HV" change it to "HVPC" and return;
#    else return "PC".
# Rationale is: two different lines called HVPC could be a hetero var1+var2,
# but any other mix of calls with multiple partialCov lines points to
# some problem (we have at least 3 well-represented alleles at this position).
# Note that if a line is PC but the same position gets a normal call (ie it
# is covRatHigh), the covRatHigh line is valid and should be used.
# The only problematic case is when all lines for that pos are at most partialCov.
#
# NOTES: 
# A. The distinction between discW and discS can usually be ignored, both
#    can be treated as discordant.
# B. SS calls are low-confidence (since not confirmed on the other strand) 
#    and should usually be ignored.
# C. Even if you want to use the SS calls, you should probably only use
#    the clear calls (HR,HET,HV) and ignore the greyzone calls.
sub callGeno {
    my ($status,$value) = ("0","0") ;
    if (@_ != 1) {
	warnq error_mess."needs 1 arg: hash ref" ;
	warnq error_mess."Got ".scalar(@_)." args: @_" ;
	return($status,$value) ;
    } 

    my $args = shift;

    unless ((defined $args->{tot_cov}) &&
	    (defined $args->{var_forward}) && 
	    (defined $args->{var_reverse}) &&
	    (defined $args->{ref_forward}) &&
	    (defined $args->{ref_reverse})) {
	
	warnq error_mess."tot_cov, var_forward, var_reverse, ref_forward, ref_reverse must be specify";
	return($status,$value) ;
    }

    my $totalCov = $args->{tot_cov};
    my $rf = $args->{ref_forward};
    my $rr = $args->{ref_reverse};
    my $vr = $args->{var_reverse};
    my $vf = $args->{var_forward};

    my $minCov = $args->{min_cov} || 10;
    my $maxhomor = $args->{maxhomor} || 0.2;
    my $lowgrey = $args->{lowgrey} || 0.3;
    my $minhet = $args->{minhet} || 0.4;
    my $maxhet = $args->{maxhet} || 0.75;
    my $highgrey = $args->{highgrey} || 0.8;
    my $minhomov = $args->{minhomov} || 0.85;

    if (! $minCov > 0) {
	warnq error_mess."called with minCov $minCov, but it must be a positive int" ;
	return($status,$value) ;
    }
    if (! $totalCov > 0) {
	warnq error_mess."called with totCov $totalCov, but it must be a positive int" ;
	return($status,$value) ;
    }
    
    # hard-coded covRat cutoffs, these shouldn't change except if testing
    # reveals they aren't good
    my ($covRatLow,$covRatHigh) = (0.2,0.8) ;

    my $covRat = ($rf + $rr + $vf + $vr) / $totalCov ;

    if ($covRat < $covRatLow) {
	# don't bother making calls
	$status = "NS" ;
	return($status,$value) ;
    }
    
    else {
	my $call1 = &callGenoStrand($rf,$vf,[$minCov,$maxhomor,$lowgrey,$minhet,$maxhet,$highgrey,$minhomov]) ;
	my $call2 = &callGenoStrand($rr,$vr,[$minCov,$maxhomor,$lowgrey,$minhet,$maxhet,$highgrey,$minhomov]) ;

	# switch if needed to have call1 >= call2
	if ($call1 < $call2) {
	    my $ctmp = $call1 ;
	    $call1 = $call2;
	    $call2 = $ctmp ;
	}

	if ($call2 == 0) {
	    if ($call1==0) {
		$status = "NS" ;
		# $value remains "0"
	    }
	    else {
		$status = "SS" ;
		if ($call1==1) {
		    $value = "HR" ;
		}
		elsif ($call1==2) {
		    $value = "LGL" ;
		}
		elsif ($call1==3) {
		    $value = "LGR" ;
		}
		elsif ($call1==4) {
		    $value = "HET" ;
		}
		elsif ($call1==5) {
		    $value = "HGL" ;
		}
		elsif ($call1==6) {
		    $value = "HGR" ;
		}
		elsif ($call1==7) {
		    $value = "HV" ;
		}
		else {
		    dieq error_mess."fix me: unknown call1 value $call1 returned by callGenoStrand!" ;
		}
	    }
	}
	else {
	    # we have sufficient coverage on both strands
	    $status = "DS" ;
	    if (($call1 - $call2) >= 3) {
		# this may not seem obvious, but trust me: it defines
		# the strong discordant zone
		$value = "discS" ;
	    }
	    elsif (($call1 - $call2) == 2) {
		# similarly this is exactly the weakly discordant zone
		$value = "discW" ;
	    }
	    elsif (($call2==1) && ($call1 <= 2)) {
		$value = "HR" ;
	    }
	    elsif (($call2 >= 6) && ($call1==7)) {
		$value = "HV" ;
	    }
	    elsif ( (($call2==3) && ($call1==4)) ||
		    (($call2==4) && ($call1<=5)) ) {
		$value = "HET" ;
	    }
	    elsif (($call2==2) && ($call1==2)) {
		$value = "NCLGL" ;
	    }
	    # all remaining zones should be NoCall, but I define them
	    # explicitely for safety
	    elsif ( (($call2>=2) && ($call1==3)) ||
		    (($call2>=5) && ($call1<=6)) ) { 
		$value = "NC" ;
	    }
	    else {
		dieq error_mess."fix me: some zones remain unexplored, this should never happen!" ;
	    }
	}

	if (($status ne "NS") && ($covRat < $covRatHigh)) {
	    if ($value eq "HV") {
		$value = "HVPC" ;
	    }
	    else {
		$value = "PC" ;
	    }
	}

	return($status,$value);
    }
}


################################
### private functions

# callGenoStrand: takes 3 args: $ref, $var, $minCov.
# $ref and $var are the number of reference and variant reads, 
# respectively, on the considered strand;
# $minCov is the minimum strand coverage.
# Uses the genotype calling parameters ($maxhomor and friends), 
# and returns the called genotype on that strand as an
# int in 0..$totalZones (7 currently), as follows:
# 0==nocall (insufficient coverage), 1==homoref, 2==lowgrey_left, 3==lowgrey_right, 
# 4==hetero, 5==highgrey_left, 6==highgrey_right, 7==homovar
sub callGenoStrand
{
    (@_ == 3) || die "callGenoStrand needs 3 args\n" ;
    my ($ref,$var,$genotype_parametresR) = @_ ;

    my ($minCov,$maxhomor,$lowgrey,$minhet,$maxhet,$highgrey,$minhomov) = @$genotype_parametresR;

    ($minCov > 0) || 
	die "in callGenoStrand: minCov ($minCov) must be positive!\n" ;
    
    # return value
    my $call = 0 ;

    my $cov = $var + $ref ;
    if ($cov >= $minCov) {
	my $ratvar = $var / $cov ;
	# call: 0==nocall, 1==homoref, 2==lowgrey_left, 3==lowgrey_right, 4==hetero,
	# 5==highgrey_left, 6==highgrey_right, 7==homovar
	if ($ratvar <= $maxhomor) {
	    $call = 1;
	}
	elsif ($ratvar <= $lowgrey) {
	    $call = 2;
	}
	elsif ($ratvar < $minhet) {
	    $call = 3;
	}
	elsif ($ratvar <= $maxhet) {
	    $call = 4;
	}
	elsif ($ratvar < $highgrey) {
	    $call = 5;
	}
	elsif ($ratvar < $minhomov) {
	    $call = 6;
	}
	else {
	    $call = 7;
	}
    }
    # else $cov < $minCov, $call == 0 already
    return($call);
}

1;
