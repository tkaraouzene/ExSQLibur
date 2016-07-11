#!/usr/bin/perl

package ANNOT;

use lib 'scripts';

use strict;
use warnings;

use my_warnings qw(dieq printq warnq warn_mess error_mess info_mess);
use my_table_functions qw(connect_database insert_values create_unique_index alter_table my_select begin_commit);
use my_vep_functions qw(parse_vep_meta_line parse_vep_info fill_vep_table check_vep_allele);
use my_vcf_functions qw(skip_vcf_meta is_indel parse_vcf_line parse_vcf_info);
use my_file_manager qw(openIN openOUT);
use feature qw(say);

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(ANNOT);

sub ANNOT {

    my $config = shift;
    my $status = 1;

    printq info_mess."Starting..." unless $config->{quiet};
    
    my $dbh = &connect_database({driver => "SQLite",
				 db => $config->{db_file},
				 user => $config->{user},
				 pswd => $config->{password},
				 verbose => 1
				});

    
    &annot_vep($config,$dbh);

    printq info_mess."Finished!" unless $config->{quiet};

    return $status;
}

##########
########

sub annot_vep {

    my ($config,$dbh) = @_;
    my $status = 1;

    my $tmp_in_file = $config->{annot_dir}."/_tmp_vep_in.vcf";

    printq info_mess."retrieving variant needed to be annotated by vep start..." if defined $config->{verbose}; 
    printq info_mess."printing it on tmp file: $tmp_in_file" if defined $config->{verbose}; 

    my $stmt = qq(SELECT id,chromosome,position,reference_allele,altered_allele
                  FROM $config->{table_name}->{variant} 
                  WHERE vep_pred is NULL);

    my $sth = $dbh->prepare($stmt);
    my $rv = $sth->execute();

    my @ids;
    my $in_fh = openOUT $tmp_in_file;

    while (my $row = $sth->fetchrow_arrayref) {

	my ($id,$chr,$pos,$ref,$alt) = @$row;
	say $in_fh join "\t",$chr,$pos,".",$ref,$alt;
	push @ids, $id;
    }
    
    close $in_fh ;

    my $nb_tot = @ids;

    printq info_mess."retrieving variant needed to be annotated by vep end..." if defined $config->{verbose}; 
    printq info_mess."$nb_tot new variants need to be annotated by VEP" if defined $config->{verbose}; 
 
    if ($nb_tot > 0) {

	my $tmp_out_file = $config->{annot_dir}."/_tmp_vep_out.vcf";
	my $log_file = $config->{annot_dir}."/log_vep.log";

	my $cmd = "variant_effect_predictor.pl ";
	$cmd .= "-i $tmp_in_file ";
	$cmd .= "-o $tmp_out_file ";
	$cmd .= "--cache_version 81 ";
	$cmd .= "--db_version 75 ";
	$cmd .= "--fork $config->{fork} " if defined $config->{fork};
	$cmd .= "--vcf ";
	$cmd .= "--no_progress ";
	$cmd .= "--force_overwrite ";
	$cmd .= "--cache";

	printq info_mess."VEP Start..." if defined $config->{verbose}; 
	`$cmd &>$log_file`;
	printq info_mess."VEP Finished!" if defined $config->{verbose}; 

	printq info_mess."update db start..." if defined $config->{verbose}; 

	my $out_fh = openIN $tmp_out_file;
	my ($meta_line,$header,$vep_meta_line) = skip_vcf_meta $out_fh,"CSQ";
	my $vep_format = parse_vep_meta_line $vep_meta_line;

	my $nb_done = 0;

	while (<$out_fh>) {

	    # if ($nb_done % 15000 == 0) {
	    # 	$dbh->commit() unless $nb_done == 0;
	    # 	printq info_mess."$nb_done / $nb_tot done, ".scalar @ids." remaining" if defined $config->{verbose}; 
	    # 	$dbh->begin_work();
	    # }

	    &begin_commit({dbh => $dbh,
			   done => $nb_done,
			   tot => $nb_tot,
			   remains => scalar @ids,
			   verbose => $config->{verbose},
			   scale => 15000
			  });


	    my ($chr,$pos,$rs,$ref,$alt,$qual,$filter,$info) = parse_vcf_line $_;
	    my $infoTable = parse_vcf_info $info;
	    
	    my $vep_info = &find_annot($infoTable,"CSQ");

	    # return array ref containing every VEP csq blocks
	    my $vep_infos = parse_vep_info $vep_info;

	    my $variant_id = shift @ids;
	    
	    foreach my $vi (@$vep_infos) {

		
		# return a hash table with key 
		my $vepTable = fill_vep_table $vi,$vep_format;	 

		my $v = join ",",(map {"'$_'"} &find_annot($vepTable,"Consequence","IMPACT","cDNA_position","CDS_position","Protein_position","Amino_acids","Codons"));

		my $stmt = qq(INSERT INTO $config->{table_name}->{overlap} (variant_id,csq,impact,cdc_position,cds_position,amino_acid,codon)
                     VALUES ($v););

		my $rv = $dbh->do($stmt);
		
	    }

	    my $stmt = qq(UPDATE $config->{table_name}->{variant}
        	      SET vep_pred = 1 
		      WHERE id = \"$variant_id\";);
	    my $rv = $dbh->do($stmt);

	    $nb_done ++;
	}

	close $out_fh;

	printq info_mess."update db finished!" if defined $config->{verbose}; 
    }

    $dbh->commit();
    $dbh->disconnect();

    printq info_mess."Finished!" unless $config->{quiet};

    return $status;
}

sub find_annot {

    my $table = shift;
    my @r;
    
   while (my $a = shift @_) {

       $table->{$a} ||= "";

       push @r,  $table->{$a};
   }

    (@r == 1) ?
	(return $r[0]) : 
	(return @r);
}
