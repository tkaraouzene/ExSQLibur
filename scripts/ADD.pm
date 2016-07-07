#!/usr/bin/perl

package ADD;

use lib 'scripts';

use strict;
use warnings;

use my_warnings qw(dieq printq warnq warn_mess error_mess info_mess);
use my_file_manager qw(openIN);
use feature qw(say);

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(ADD);

sub ADD {

    my $config = shift;
    my $status = 1;
	my $add;
   
	printq info_mess."Starting..." if $config->{verbose};
	
	    my $dbh = &connect_database({driver => "SQLite",
				 db => $config->{db_file},
				 user => $config->{user},
				 pswd => $config->{password},
				 verbose => 1
				});

	

	if (defined $config->{add_exome}) {
		
		my $fh = openIN $config->{add_exome};
		my $header = <$fh>;
		close $fh;
		
		if (&check_exome_header($fh)) {
		
			&insert_values($dbh,
						   {table => $config->{table_name}->{exome},
							csv_file => $config->{add_exome},
							verbose => $config->{verbose}});
							
		} or dieq error_mess."add_exome failed";
		
		$add++;
	} 
	
	if (defined $config->{add_pathology}) {
	
		my $fh = openIN $config->{add_pathology};
		my $header = <$fh>;
		close $fh;

		if (&check_pathology_header($fh)) {

			&insert_values($dbh,
						   {table => $config->{table_name}->{pathology},
							csv_file => $config->{add_pathology},
							verbose => $config->{verbose}});
		} or dieq error_mess."add_pathology failed";
		
		$add++;
	} 
	
	if (defined $config->{add_patient}) {
	
		my $fh = openIN $config->{add_patient};
		my $header = <$fh>;
		close $fh;

		if (&check_patient_header($fh)) {
		
			my ($patient_id,$sex,$f1,$f2,$is_aligned,$comment,$patho,$seq_platform,$seq_model,$seq_place,$seq_date) = split /\t/;
			my $is_runs_ace = 0;

			my $exome_id = &my_select($dbh,
									  {table => $config->{table_name}->{exome},
									   fields => ["platform","model","place","date"],
									   values => [$seq_platform,$seq_model,$seq_place,$seq_date],
									   what => ["id"],
									   operator => "AND",
									   verbose => $config->{verbose}
									  }) or dieq error_mess."$patient_id: no exome_id found for this patient";

			&insert_values($dbh,
						   {table => $config->{table_name}->{patient},
							fields => ["id","sex","reads_file1","reads_file2","is_aligned","is_runs_ace","comment","pathology","exome"],
							values => [$patient_id,$sex,$f1,$f2,$is_aligned,$is_runs_ace,$comment,$patho,$exome_id],
							verbose => $config->{verbose}});
		}
		
		$add++;
	} 
	
	if ($add) {
	
		printq info_mess."$add file(s) added" if $config->{verbose};
	
	} else {
	
		warnq warn_mess."Nothing to add, you should specify one of: --add_exome, --add_pathology or --add_patient";
	}

	$dbh->disconnect();

    printq info_mess."Finished!" if $config->{verbose};

return 1;
}


#######
######

sub check_exome_header {

	my $header = shift;
	my $status;
	
	if ($header eq "platform\tmodel\tplace\tdate\texome_capture\tcomment") {
	
		$status = 1;
	
	} else {
	
		warnq warn_mess."unexpected exome header";
	
	}
	
	return $status;
}

sub check_pathology_header {

	my $header = shift;
	my $status;
	
	if ($header eq "name\tdescription") {
	
		$status = 1;
	
	} else {
	
		warnq warn_mess."unexpected exome header";
	
	}
	
	return $status;
}


sub check_patient_header {

	my $header = shift;
	my $status;
	
	if ($header eq "id\tsex\treads_file1\treads_file2\tis_aligned\tcomments\tpathology\tseq_plateforme\tseq_model\tseq_place\tseq_date") {
	
		$status = 1;
	
	} else {
	
		warnq warn_mess."unexpected exome header";
	
	}
	
	return $status;
}


