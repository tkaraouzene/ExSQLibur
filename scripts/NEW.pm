#!/usr/bin/env perl

package NEW;

use strict;
use warnings;

use DBI;
use feature qw(say);
use my_warnings qw(dieq printq warnq warn_mess error_mess info_mess);
use my_file_manager qw(openIN);
use my_table_functions qw(connect_database create_table insert_values drop_table create_unique_index my_select alter_table);
use my_vep_functions qw(vep_impact vep_csq);
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(NEW);

sub NEW {

    my $config = shift;
    my $status = 1;
    printq info_mess."Starting..." if $config->{verbose};
    
	my $dbh = &connect_database({driver => "SQLite",
			 db => $config->{db_file},
			 user => $config->{user},
			 pswd => $config->{password},
			 verbose => 1
			});

	&init_table($config,$dbh);
	
	    &insert_values($dbh,
		   {table => $config->{table_name}->{vep_impact},
		    fields => ["impact","comment"],
		    from_hash => &vep_impact(),
		    verbose => $config->{verbose}});

    &insert_values($dbh,
                   {table => $config->{table_name}->{vep_csq},
                    fields => ["consequence","comment","so_accession","display_term","impact"],
                    from_hash => &vep_csq(),
                    verbose => $config->{verbose}});

    &insert_values($dbh,
                   {table => $config->{table_name}->{call},
                    fields => ["id","name","strand"],
                    from_hash => &my_call(),
                    verbose => $config->{verbose}});
	
	TODO: I Have to move following insert into ADD Pathology 
    # &insert_values($dbh,
		   # {table => $config->{table_name}->{pathology},
		    # csv_file => $config->{patho_file},
		    # verbose => $config->{verbose}});
    
    # &update_table_pathology($dbh,$config);
    ##

	TODO: I Have to move following insert into ADD Exome 
    # &insert_values($dbh,
		   # {table => $config->{table_name}->{exome},
		    # csv_file => $config->{exome_file},
		    # verbose => $config->{verbose}});
    
    # &create_unique_index($dbh,{index_name => "ind_uni_model_place_date",
			       # table => $config->{table_name}->{exome},
			       # fields => "model,place,date"});
    ##
	
	
	# printq info_mess."$config->{table_name}->{patient}: retrieving data from $config->{patient_file}";

   #  currently this phase is done in NEW module but will be move in a new one (ADD patient)
    # my $fh = openIN $config->{patient_file};

    # <$fh>;
    # while (<$fh>) {
	# chomp;

	# my ($patient_id,$sex,$f1,$f2,$is_aligned,$comment,$patho,$seq_platform,$seq_model,$seq_place,$seq_date) = split /\t/;
	# my $is_runs_ace = 0;

	# my $exome_id = &my_select($dbh,
				  # {table => $config->{table_name}->{exome},
				   # fields => ["platform","model","place","date"],
				   # values => [$seq_platform,$seq_model,$seq_place,$seq_date],
				   # what => ["id"],
				   # operator => "AND",
				   # verbose => $config->{verbose}}) or dieq error_mess."$patient_id: no exome_id found for this patient";

	# &insert_values($dbh,
		       # {table => $config->{table_name}->{patient},
				# fields => ["id","sex","reads_file1","reads_file2","is_aligned","is_runs_ace","comment","pathology","exome"],
				# values => [$patient_id,$sex,$f1,$f2,$is_aligned,$is_runs_ace,$comment,$patho,$exome_id],
				# verbose => $config->{verbose}});
    # }

    # close $fh;

    $dbh->disconnect();
    
    printq info_mess."Finished!" if $config->{verbose};
    
    return $status;
}

#############
#############

sub init_table {
	
	my ($config,$dbh) = @_;
	
	printq info_mess."start" if $config->{verbose}; 

	&create_table($dbh,
		  {name => "VARCHAR(25) PRIMARY KEY NOT NULL",
		   description => "VARCHAR(250)",
		   is_added => "BOOLEAN"},
		  {table => $config->{table_name}->{pathology},
		   verbose => $config->{verbose}						      
		  }) or dieq error_mess."failed";

	&create_table($dbh,
		  {id => "INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL",
		   platform => "VARCHAR(25)",
		   model => "VARCHAR(25)",
		   place => "VARCHAR(25)",
		   date => "DATE",
		   exome_capture => "VARCHAR(150)",
		   comment => "VARCHAR(250)"},
		  {table => $config->{table_name}->{exome},
		   verbose => $config->{verbose}						      
		  });

	&create_table($dbh,
		  {id => "VARCHAR(20) PRIMARY KEY NOT NULL",
		   sex => "CHAR(1)",
		   reads_file1 => "VARCHAR(150) NOT NULL",
		   reads_file2 => "VARCHAR(150)",
		   is_aligned => "BOOLEAN",
		   is_runs_ace => "BOOLEAN",
		   comment => "VARCHAR(250)",
		   pathology => "INT UNSIGNED NOT NULL",
		   exome => "INT UNSIGNED NOT NULL"},
		  {table => $config->{table_name}->{patient},
		   verbose => $config->{verbose},					      
		   fk => [{name => "fk_patho",
			   ref_table => $config->{table_name}->{pathology},
			   ref_fields => "id",
			   table_fields => "pathology"},
			  {name => "fk_exome",
			   ref_table => $config->{table_name}->{exome},
			   ref_fields => "id",
			   table_fields => "exome"}
			   ]
		  });

	&create_table($dbh,
		  {id => "INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL",
		   chromosome => "VARCHAR(2)",
		   position => "INT UNSIGNED",
		   referance_allele => "VARCHAR(20)",
		   altered_allele => "VARCHAR(20)",
		   rs_id => "VARCHAR(15)"},
		  {table => $config->{table_name}->{variant},
		   verbose => $config->{verbose}						      
		  });

	&create_table($dbh,
		  {id => "CHAR(1) PRIMARY KEY NOT NULL",
		   name => "VARCHAR(8) NOT NULL",
		   strand => "CHAR(2)",
		   comment => "VARCHAR(150)"},
		  {table => $config->{table_name}->{call},
		   verbose => $config->{verbose}
		  });

	&create_table($dbh,
		  {id => "INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL",
		   patient_id => "VARCHAR(20) NOT NULL",
		   variant_id => "INTEGER NOT NULL",
		   call_id => "CHAR(1)"},
		  {table => $config->{table_name}->{carry},
		   verbose => $config->{verbose},
		   fk => [{name => "fk_patient_id",
			   ref_table => $config->{table_name}->{patient},
			   ref_fields => "id",
			   table_fields => "patient_id"},
			  {name => "fk_variant_id",
			   ref_table => $config->{table_name}->{variant},
			   ref_fields => "id",
			   table_fields => "variant_id"},
			  {name => "fk_call_id",
			   ref_table => $config->{table_name}->{call},
			   ref_fields => "id",
			   table_fields => "call_id"}
					   ]			      
		  });

	&create_table($dbh,
		  {id => "VARCHAR(20) PRIMARY KEY NOT NULL",
		   name => "VARCHAR(15)",
		   start => "INT UNSIGNED NOT NULL",
		   end => "INT UNSIGNED NOT NULL",
		   strand => "CHAR(1) NOT NULL",
		   source => "VARCHAR(25)",
		   biotype => "VARCHAR(25)"},
		  {table => $config->{table_name}->{gene},
		   verbose => $config->{verbose},						      
		  });

	&create_table($dbh,
		  {id => "INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL",
		   name => "VARCHAR(20)",
		   version => "INT UNSIGNED"},
		  {table => $config->{table_name}->{transcript_set},
		   verbose => $config->{verbose}						      
		  });

	&create_table($dbh,
		  {id => "VARCHAR(20) PRIMARY KEY NOT NULL",
		   name => "VARCHAR(25)",
		   start => "INT UNSIGNED NOT NULL",
				   end => "INT UNSIGNED NOT NULL",
				   strand => "CHAR(1) NOT NULL",
		   gene_id => "VARCHAR(20) NOT NULL",
		   source => "VARCHAR(25)",
		   ccds_id => "VARCHAR(15)"},
		   {table => $config->{table_name}->{transcript},
				   verbose => $config->{verbose},
				   fk => [{name => "fk_gene_id",
						 ref_table => $config->{table_name}->{gene},
						 ref_fields => "id",
						 table_fields => "gene_id"},
					   ]
				  });

	&create_table($dbh,
		  {impact => "VARCHAR(8) PRIMARY KEY NOT NULL",
		   comment => "VARCHAR(100)"},
		  {table => $config->{table_name}->{vep_impact},
		   verbose => $config->{verbose},						      
		  });

	&create_table($dbh,
				  {consequence => "VARCHAR(30) PRIMARY KEY NOT NULL",
		   comment => "VARCHAR(100)",
		   so_accession => "VARCHAR(12)",
		   display_term => "VARCHAR(30)",
		   impact => "VARCHAR(8) NOT NULL"},
				  {table => $config->{table_name}->{vep_csq},
				   verbose => $config->{verbose},
		   fk => [{name => "fk_impact",
						   ref_table => $config->{table_name}->{vep_impact},
						   ref_fields => "id",
						   table_fields => "impact"}
			   ]
		  });

	&create_table($dbh,
		  {id => "INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL",
		   variant_id => "INT NOT NULL",
		   transcript_id => "VARCHAR(20)",
		   csq_id => "INT NOT NULL",
		   cdc_position => "INT NOT NULL",
		   cds_position => "INT NOT NULL"},
		  {table => $config->{table_name}->{overlap},
		   verbose => $config->{verbose}, 	      
		   fk => [{name => "fk_transcript_id",
			   ref_table => $config->{table_name}->{transcript},
			   ref_fields => "id",
			   table_fields => "transcript_id"},
			  {name => "fk_variant_id",
			   ref_table => $config->{table_name}->{variant},
			   ref_fields => "id",
			   table_fields => "variant_id"},
			  {name => "fk_csq_id",
			   ref_table => $config->{table_name}->{vep_csq},
			   ref_fields => "id",
			   table_fields => "csq_id"}
			   ]
		  });
	
	printq info_mess."end" if $config->{verbose}; 

	return 1;
}

sub update_table_pathology {

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

	
	$stmt = qq(UPDATE $config->{table_name}->{pathology} SET is_added = 1
                   WHERE name = \"$patho_name\";);

        $dbh->do($stmt) or die $DBI::errstr;
	printq info_mess."$patho_name: Finished" if $config->{verbose};
    }

    printq info_mess."Finished" if $config->{verbose};
    
    return 1;
}

sub my_call {

	
	my $calls = {
	
		"1" => ["HR","DS"],
		"2" => ["HET","DS"],
		"3" => ["HV","DS"],
		"4" => ["NC","DS"],
		"5" => ["NCLGL","DS"],
		"6" => ["HVPC","DS"],
		"7" => ["PC","DS"],
		"8" => ["discW","DS"],
		"9" => ["discS","DS"],

		a => ["HR","SS"],
		b => ["HET","SS"],
		c => ["HV","SS"],
		d => ["LGL","SS"],
		e => ["LGR","SS"],
		f => ["HGL","SS"],
		g => ["HGR","SS"],
		h => ["HVPC","SS"],
		i => ["PC","SS"],

		0 => ["","NS"],
		"*" => ["NC",""]
	};

	return $calls;
}
			