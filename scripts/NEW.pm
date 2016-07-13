#!/usr/bin/env perl

package NEW;

use strict;
use warnings;

use DBI;
use feature qw(say);
use my_warnings qw(dieq printq warnq warn_mess error_mess info_mess);
use my_file_manager qw(openIN);
use my_table_functions qw(connect_database begin_commit create_table insert_values my_select create_unique_index);
use my_vep_functions qw(parse_vep_meta_line parse_vep_info fill_vep_table check_vep_allele vep_impact vep_csq);
use my_vcf_functions qw(skip_vcf_meta is_indel parse_vcf_line parse_vcf_info);

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(NEW);

sub NEW {

    my $config = shift;
    my $status = 1;

    printq info_mess."Starting..." unless $config->{quiet};
    
    my $dbh = &connect_database({driver => "SQLite",
				 db => $config->{db_file},
				 user => $config->{user},
				 pswd => $config->{password},
				 verbose => $config->{verbose}
				});

    $dbh->begin_work();

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

    $dbh->commit();

    &insert_exac($dbh,$config);

    $dbh->disconnect();
    
    printq info_mess."Finished!" unless $config->{quiet};
    
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

	&create_unique_index($dbh,{index_name => "ind_uni_model_place_date",
				   table => $config->{table_name}->{exome},
				   fields => "model,place,date"});

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
		       reference_allele => "VARCHAR(20)",
		       altered_allele => "VARCHAR(20)",
		       rs_id => "VARCHAR(15)",
		       exac_maf => "DECIMAL(10,9)",
		       vep_pred => "BOOLEAN"},
		      {table => $config->{table_name}->{variant},
		       verbose => $config->{verbose}						      
		      });
	
	&create_unique_index($dbh,{index_name => "ind_uni_chr_pos_ref_alt",
				   table => $config->{table_name}->{variant},
				   fields => "chromosome,position,reference_allele,altered_allele"});

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

	&create_unique_index($dbh,{index_name => "ind_uni_patient_variant",
				   table => $config->{table_name}->{carry},
				   fields => "patient_id,variant_id"});

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

	# &create_table($dbh,
	# 	  {id => "INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL",
	# 	   variant_id => "INT NOT NULL",
	# 	   transcript_id => "VARCHAR(20)",
	# 	   csq_id => "INT NOT NULL",
	# 	   cdc_position => "INT NOT NULL",
	# 	   cds_position => "INT NOT NULL"},
	# 	  {table => $config->{table_name}->{overlap},
	# 	   verbose => $config->{verbose}, 	      
	# 	   fk => [{name => "fk_transcript_id",
	# 		   ref_table => $config->{table_name}->{transcript},
	# 		   ref_fields => "id",
	# 		   table_fields => "transcript_id"},
	# 		  {name => "fk_variant_id",
	# 		   ref_table => $config->{table_name}->{variant},
	# 		   ref_fields => "id",
	# 		   table_fields => "variant_id"},
	# 		  {name => "fk_csq_id",
	# 		   ref_table => $config->{table_name}->{vep_csq},
	# 		   ref_fields => "id",
	# 		   table_fields => "csq_id"}
	# 		   ]
	# 	  });
	
	&create_table($dbh,
		      {id => "INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL",
		       variant_id => "INT NOT NULL",
		       transcript_id => "VARCHAR(20)",
		       csq => "VARCHAR(200)",
		       cdc_position => "INT",
		       cds_position => "INT",
		       protein_position => "INT",
		       amino_acid =>  "VARCHAR(3)",
		       codon => "VARCHAR(7)",
		       impact => "VARCHAR(8)",},
		      {table => $config->{table_name}->{overlap},
		       verbose => $config->{verbose}, 	      
		       fk => [{name => "fk_variant_id",
			       ref_table => $config->{table_name}->{variant},
			       ref_fields => "id",
			       table_fields => "variant_id"},
			      {name => "fk_impact",
			       ref_table => $config->{table_name}->{vep_impact},
			       ref_fields => "impact",
			       table_fields => "impact"}
			   ]
		      });


	&create_unique_index($dbh,{index_name => "ind_uni_var_transcript",
				   table => $config->{table_name}->{overlap},
				   fields => "variant_id,transcript_id"});

	printq info_mess."end" if $config->{verbose}; 

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

sub insert_exac {

    my ($dbh,$config) = @_;
    my $exac_file = $config->{exac_dir}."/ExAC.r0.3.sites.vep81_GRC37.vcf.gz";

    if (-e $exac_file) {

	printq info_mess."exac start" if defined $config->{verbose};

	my $exac_fh = openIN $exac_file;
	my ($meta_line,$header,$vep_meta_line) = skip_vcf_meta $exac_fh,"CSQ";
	my $vep_format = parse_vep_meta_line $vep_meta_line;
	my $nb_done = 0;
	
	my @good_info = ("CSQ","AC_Adj","AN_Adj");

	while (<$exac_fh>) {

	    &begin_commit({dbh => $dbh,
			   done => $nb_done,
			   scale => 20000,
			   verbose => $config->{verbose}
			  });
 
	    my ($chr,$pos,$rs,$ref,$alts,$qual,$filter,$info) = parse_vcf_line $_;
	    
	    next unless $filter eq "PASS";
	    
	    my $infoTable = parse_vcf_info $info;
	    my ($vep_info,$nb_alts_allele,$nb_tot_allele) = &find_annot($infoTable,@good_info);
	
	    my @alts = split /,/, $alts;
	    my @nb_alts_allele = split /,/, $nb_alts_allele;

	    dieq error_mess."@alts != @nb_alts_allele" unless @alts == @nb_alts_allele;

	    dieq error_mess."cannot find vepInfo" unless defined $vep_info;
	    
	    my $vep_infos = parse_vep_info $vep_info;

	    foreach my $i (0..$#alts) {

		my $alt = $alts[$i];
		my $nb_alt_allele = $nb_alts_allele[$i];

		my $maf = $nb_alt_allele / $nb_tot_allele;

		dieq error_mess."unexpected maf: $maf" if $maf > 1 || $maf < 0; 
		
                my $v = join ",", map {"'$_'"} $chr,$pos,$ref,$alt,$maf;

		my $stmt = qq(INSERT INTO $config->{table_name}->{variant} (chromosome,position,reference_allele,altered_allele,exac_maf) 
	                      VALUES ($v););
		
		$dbh->do($stmt);

		my $variant_id = &my_select($dbh,
					    {table => $config->{table_name}->{variant},
					     select => ["id"],
					     fields => ["chromosome","position","reference_allele","altered_allele"],
					     values => [$chr,$pos,$ref,$alt],
					     operator => "AND",
					     verbose => $config->{verbose}
					    }) or dieq error_mess."$chr:$pos:$ref:$alt: no such variant_id found in $config->{table_name}->{variant}"; 

	      VI: foreach my $vi (@$vep_infos) {
		  
		  my $vepTable = fill_vep_table $vi,$vep_format;	 
		  
		  
		  my ($which_allele,$transcript,$csqs,$impact,$cdna,$cds,$prot,$aa,$codon) = 
		      &find_annot($vepTable,"Allele","Feature","Consequence","IMPACT",
				  "cDNA_position","CDS_position","Protein_position",
				  "Amino_acids","Codons");
		  
		  # check if the VEP csq is about the same Alt allele than the VCF line
		  next VI unless &check_vep_allele($ref,$alt,$which_allele,$chr,$pos);  

		  $v = join ",", map {"'$_'"} $variant_id,$transcript,$csqs,$impact,$cdna,$cds,$prot,$aa,$codon;

		  $stmt = qq(INSERT INTO $config->{table_name}->{overlap} (variant_id,transcript_id,csq,impact,cdc_position,cds_position,protein_position,amino_acid,codon)
                             VALUES ($v););
		  $dbh->do($stmt);
	      }
		
	    }
	    $nb_done++;
	}

	$dbh->commit();

	printq info_mess."exac end" if defined $config->{verbose};

    }

    return 1;
}
