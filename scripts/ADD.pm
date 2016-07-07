#!/usr/bin/perl

package ADD;

use lib 'scripts';

use strict;
use warnings;

use my_warnings qw(dieq printq warnq warn_mess error_mess info_mess);
use my_table_functions qw(connect_database insert_values create_unique_index alter_table my_select);
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
		chomp(my $header = <$fh>);
		close $fh;
		
		if (&check_exome_header($header)) {
		
			&insert_values($dbh,
						   {table => $config->{table_name}->{exome},
							csv_file => $config->{add_exome},
							verbose => $config->{verbose}
							}) or dieq error_mess."add_exome failed";
							
		    &create_unique_index($dbh,{index_name => "ind_uni_model_place_date",
			       table => $config->{table_name}->{exome},
			       fields => "model,place,date"});
		} 
		
		$add++;
	} 
	
	if (defined $config->{add_pathology}) {
	
		my $fh = openIN $config->{add_pathology};
		chomp(my $header = <$fh>);
		close $fh;

		if (&check_pathology_header($header)) {

			&insert_values($dbh,
						   {table => $config->{table_name}->{pathology},
							csv_file => $config->{add_pathology},
							verbose => $config->{verbose}}) or dieq error_mess."add_pathology failed";
		
			&update_table_variant($dbh,$config);
		}
		
		$add++;
	} 
	
	if (defined $config->{add_patient}) {
	
		my $fh = openIN $config->{add_patient};
		chomp(my $header = <$fh>);
		close $fh;

		
		if (&check_patient_header($header)) {
		
			my $fh2 = openIN $config->{add_patient};

			<$fh>;
			while (<$fh>) {
	
				chomp;
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
		
			close $fh2;
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
	
		warnq warn_mess."unexpected exome header: $header";
	
	}
	
	return $status;
}

sub check_pathology_header {

	my $header = shift;
	my $status;
	
	if ($header eq "name\tdescription") {
	
		$status = 1;
	
	} else {
	
		warnq warn_mess."unexpected exome header: $header";
	
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

sub update_table_variant {

    my ($dbh,$config) = @_;
    
    printq info_mess."Start..." if $config->{verbose};
    
    my $stmt = qq(SELECT name FROM $config->{table_name}->{pathology}
                  WHERE is_added IS NULL
                  ;);

    my $sth = $dbh->prepare($stmt);
    my $rv = $sth->execute() or die $DBI::errstr;

    while (my $row = $sth->fetchrow_arrayref()) {

        my $patho_name = $row->[0];

		printq info_mess."$patho_name: Start..." if $config->{verbose};

        my $new_columns = {
            "nb_ref_".$patho_name => "INT UNSIGNED",
			"nb_het_".$patho_name => "INT UNSIGNED",
			"nb_homo_".$patho_name => "INT UNSIGNED",
			"maf_".$patho_name => "DECIMAL(1,5)"
        };

        # TK: 04/07/2016
        # TODO:
        # for now it add new columns in a random order
        # need to fix that soon
		&alter_table($dbh,{table => $config->{table_name}->{variant},
			   action => "ADD",
			   col_name => $_,
			   col_type => $new_columns->{$_}}) foreach keys %$new_columns;
	
		$stmt = qq(UPDATE $config->{table_name}->{pathology}
        		   SET is_added = 1 
				   WHERE name = \"$patho_name\";);

        $dbh->do($stmt) or die $DBI::errstr;
		printq info_mess."$patho_name: Finished" if $config->{verbose};
    }

    printq info_mess."Finished" if $config->{verbose};
    
    return 1;
}

