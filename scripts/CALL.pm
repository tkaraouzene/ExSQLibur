#!/usr/bin/perl

package CALL;

use lib 'scripts';

use strict;
use warnings;

use Parallel::ForkManager;
use my_warnings qw(dieq printq warnq warn_mess error_mess info_mess get_day);
use my_table_functions qw(connect_database insert_values my_select);
use my_snph_functions qw(parse_snph_line parse_snph_variant snph_indel_position_recalibration);
use my_genotype_calling_functions qw(geno_code);
use callGenotype_TK qw(callGeno);
use feature qw(say);
use my_file_manager qw(openIN);

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(CALL);

sub CALL {

    my $config = shift;
    my $status = 1;

    printq info_mess."Starting..." unless $config->{quiet};
    
    my $dbh = &connect_database({driver => "SQLite",
				 db => $config->{db_file},
				 user => $config->{user},
				 pswd => $config->{password},
				});

    foreach my $chr (1..22,"X","Y","mito") {
	
	printq info_mess."chr$chr: Start..." if $config->{verbose};

	my $convert_pos_table = {};
	my $snph_file = join "/", $config->{snph_dir},$chr,$config->{project_name}.".snp.sorted";
	my $snph_fh = openIN $snph_file;
	my $i = 1;

	$dbh->begin_work();

	<$snph_fh>;
	while (<$snph_fh>) {

	    my ($chr,$pos,$var,$seq_ref,$seq_alt,$patient_id,$cover,$vf,$rf,$vr,$rr) = parse_snph_line $_,0,1..5,8,11..14;
	    my ($ref,$alt,$is_indel) = parse_snph_variant $var;
	    
	    snph_indel_position_recalibration \$ref,\$alt,\$pos,$chr,$var,$seq_ref,$seq_alt,$is_indel,$convert_pos_table if $is_indel;
	    
	    dieq error_mess."$is_indel: at this point alt and ref alleles should be defined" unless defined $ref && defined $alt;
	  
	    my @values = map {"'$_'"} ($chr,$pos,$ref,$alt);
	    my $v = join ",", @values;

	    my $stmt = qq(INSERT OR IGNORE INTO $config->{table_name}->{variant} (chromosome,position,reference_allele,altered_allele) 
	                   VALUES ($v););
	    
	    my $rv = $dbh->do($stmt);

	    my $variant_id = &my_select($dbh,
	    				{table => $config->{table_name}->{variant},
	    				 select => ["id"],
	    				 fields => ["chromosome","position","reference_allele","altered_allele"],
	    				 values => [$chr,$pos,$ref,$alt],
	    				 operator => "AND",
	    				 verbose => $config->{verbose}
	   				}) or dieq error_mess."$chr:$pos:$ref:$alt: no such variant_id found in $config->{table_name}->{variant}"; 

	    my ($status, $value) = &callGeno({tot_cov => $cover,
					      var_forward => $vf,
					      var_reverse => $vr,
					      ref_forward => $rf,
					      ref_reverse => $rr,
					     });
	    
	    my $call_id = &geno_code($status,$value) || "*";

	    @values = map {"'$_'"} ($patient_id,$variant_id,$call_id);
	    $v = join ",", @values;

	    $stmt = qq (INSERT INTO $config->{table_name}->{carry} (patient_id,variant_id,call_id) 
                       VALUES ($v););

	    
	    $rv = $dbh->do($stmt);
	    $i++;
	}
	close $snph_fh;
	$dbh->commit();

	printq info_mess."chr$chr: Finished!" if $config->{verbose};
    }
    
    $dbh->disconnect();

    printq info_mess."Finished!" unless $config->{quiet};

    return 1;	
}
