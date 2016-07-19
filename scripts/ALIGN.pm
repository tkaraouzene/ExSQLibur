#!/usr/bin/perl

package ALIGN;

use lib 'mylib';

use strict;
use warnings;

use DBI;
use File::Basename;
use my_warnings qw(dieq printq warnq warn_mess error_mess info_mess get_day);
use feature qw(say);
use my_table_functions qw(connect_database);
use my_file_manager qw(openOUT);
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(ALIGN);

sub ALIGN {

    my $config = shift;
    my $status = 1;

    printq info_mess."Starting..." unless defined $config->{quiet};
    
    my $dbh = &connect_database({driver => "SQLite",
				 db => $config->{db_file},
				 user => $config->{user},
				 pswd => $config->{password},
				 verbose => $config->{verbose}
				});

    $ENV{MAGIC} = $config->{project_name};

    &update_runs_ace($config,$dbh);
    
    chdir $config->{align_dir};
	
    my $metaDB_dir = fileparse $config->{align_dir}."/MetaDB";

    &init_align($config) unless -d $metaDB_dir;

    my $tbly_cmd = qq(./tbly MetaDB <<EOF
parse runs.ace
save
quit
EOF
);
    
    `$tbly_cmd`;

    my $fh = openOUT "LIMITS", {mode => ">>"};

    say $fh "setenv targets \"mito genome\"";
    
    close $fh;
    
    my $day = get_day();
    my $log_dir = fileparse($config->{align_log_dir})."/".$day;
    
    dieq error_mess."cannot mkdir $log_dir: $!" unless -d $log_dir || mkdir $log_dir;

    my @process;

    if ($config->{process}) {

	@process = split /,/, $config->{process};

    } else {

	@process = ("a0","ALIGN","WIGGLE","SNV");
    }

    foreach my $process (@process) {
	
    	my $log_file  = $log_dir."/log_".$process;
	
    	if (-e $log_file) {
	    
    	    my $i = 0;
    	    my $lf = $log_file;
	    
    	    while (-e $lf) {
		
    		$i++;
    		$lf = $log_file."_".$i;
    	    }
	    
    	    $log_file = $lf;
    	}
	
    	$log_file .= ".log";
	
    	my $cmd = "./MAGIC";
    	$cmd .= " ".$process;
    	$cmd .= " &>".$log_file;

    	printq info_mess."MAGIC $process &>$config->{align_dir}/$log_file start" if defined $config->{verbose};
	`$cmd`;
    	printq info_mess."MAGIC $process &>$config->{align_dir}/$log_file finshed" if defined $config->{verbose};

    }

    # &update_aligned($config,$dbh);
    
    $dbh->disconnect();
    
    printq info_mess."Finished!" unless defined $config->{quiet};
    return $status;
}

sub init_align {
    
    my $config = shift;

    printq info_mess."Starting..." if defined $config->{verbose};
    
    my $day = get_day();
    my $log_dir = fileparse($config->{align_log_dir})."/".$day;
    dieq error_mess."cannot mkdir $log_dir: $!" unless -d $log_dir || mkdir $log_dir;
    my $cmd = "$ENV{MAGIC_SRC}/waligner/scripts/MAGIC init DNA &>".$log_dir."/log_init_dna.log";

    `$cmd`;
    
    my $tmp_dir = basename $config->{tmp_align_dir};

    my $fh = openOUT "LIMITS", {mode => ">>"};
    say $fh "setenv TMPDIR $tmp_dir";
    close $fh;

    printq info_mess."Finished" if defined $config->{verbose};

    return;

}

sub update_runs_ace {

    my ($config,$dbh) = @_;
   
    my $stmt = qq(SELECT p.id,
                         p.reads_file1,
                         p.reads_file2,
                         p.pathology,
                         e.platform,
                         e.model,
                         e.place
                  FROM $config->{table_name}->{patient} AS p
                  INNER JOIN $config->{table_name}->{exome} AS e
                  ON p.exome = e.id
                  ); 

    # $stmt .= "AND p.is_runs_ace = 0" if -e $config->{runs_ace_file};
    $stmt .= ";";

    my @patient_to_update;

    my $runs_ace_fh = openOUT $config->{runs_ace_file};

    my $sth = $dbh->prepare($stmt);
    my $rv = $sth->execute() or die $DBI::errstr;
    
    while (my $row = $sth->fetchrow_arrayref()) {

	my ($id,$f1,$f2,$patho,$platform,$model,$place) = @$row;

	warnq warn_mess."$id: f1:  $config->{raw_data}.\"/\".$f1 not found" unless -e  $config->{fastq_dir}."/".$f1;
	warnq warn_mess."$id: f1: $config->{raw_data}.\"/\".$f2 not found" unless -e  $config->{fastq_dir}."/".$f2;

       	my $runs_ace_info;
	print $runs_ace_fh "\n";
	say $runs_ace_fh "Run $id";
	say $runs_ace_fh "FILE fastq/1 Fastq/$f1";
	say $runs_ace_fh "FILE fastq/2 Fastq/$f2" if $f2;
	say $runs_ace_fh "Title \"$id\"";
	say $runs_ace_fh "Project $config->{project_name}";
	say $runs_ace_fh "Project $place";
	say $runs_ace_fh "Project $patho";
	say $runs_ace_fh $platform;
	say $runs_ace_fh "Wiggle";
	say $runs_ace_fh "SNP";
	say $runs_ace_fh "Exome";
	say $runs_ace_fh "Exome_capture";
	say $runs_ace_fh "Paired_end" if $f2;
	say $runs_ace_fh "";
	
    	push @patient_to_update, $id
    }
    
    $sth->finish();

    if (@patient_to_update) {

	printq info_mess."Updating patient...";

	say $runs_ace_fh "Run All_runs";
	say $runs_ace_fh "Project $config->{project_name}";
	
	$dbh->begin_work();

	foreach my $patient (@patient_to_update) {
	    
	    printq info_mess."$patient added to $config->{runs_ace_file}" if defined $config->{verbose};

	    $stmt = qq(UPDATE Patient SET is_runs_ace = 1 WHERE id = \"$patient\";);
	    $dbh->do($stmt) or die $DBI::errstr;

	    say $runs_ace_fh "Runs ".$patient;
	}

	$dbh->commit();
	
	printq info_mess."Update patient finished!";
    }
    
    close $runs_ace_fh;

    return 1;
}
