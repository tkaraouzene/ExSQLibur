#!/usr/bin/perl
use lib 'scripts';
use strict;
use warnings;
use my_warnings qw(get_time dieq printq warnq warn_mess error_mess info_mess);
use Getopt::Long;
use File::Path qw(rmtree);
use NEW qw(NEW);
use ALIGN qw(ALIGN);
use ADD qw(ADD);
use CALL qw(CALL);
use ANNOT qw(ANNOT);
use USAGE qw(USAGE);
use backup qw(backup);

print &header;

# configure from command line opts
my $config = &configure(\@ARGV);

# run the main sub routine
&main($config);

###############
############

sub main {
    my $config = shift;
    printq info_mess."Starting..." unless $config->{quiet};
    
    &backup($config) if defined $config->{backup} and $config->{mode} ne "NEW";

    if ($config->{mode} eq "NEW") {
	
	&NEW($config);
	
    } elsif ($config->{mode} eq "ALIGN") {
	
	&ALIGN($config);
	
    }  elsif ($config->{mode} eq "ADD") {
	
	&ADD($config);
	
    }  elsif ($config->{mode} eq "CALL") {
	
	&CALL($config);
	
    }  elsif ($config->{mode} eq "ANNOT") {
	
	&ANNOT($config);
	
    } else {
	
	dieq error_mess."Unexpected mode: $config->{mode}".&USAGE($config);
    }
    
    printq info_mess."Finished!" unless $config->{quiet};
}


###############
############

sub configure {

	# sets up configuration hash that is used throughout the script
	
    my @ARGV_copy = @ARGV;
    my $args = shift;
    my $mode = shift @$args;   
    my $config = {};
    
    $config->{mode} = $mode;
	
    get_option($config);
	
    if ((defined $config->{help}) ||
	(!defined $config->{mode}) ||
	(!$args)) {	
	&USAGE($config);
	die;
    }

    chomp(my $pwd = `pwd`);

    if ($config->{project_name}) {

	$config->{project_name} =~ s/\/$//;
	$config->{db_dir} = $config->{project_name}."/DB";
	$config->{db} = $config->{db_dir}."/".$config->{project_name};
	$config->{align_dir} = $config->{project_name}."/Align_data";
	$config->{backup_dir} = $config->{project_name}."/Backup";
	$config->{db_file} = $config->{db}.".db";
    }

    $config->{data_dir} = $pwd."/data";	
    $config->{exac_dir} = $config->{data_dir}."/ExAC";
    $config->{scripts_dir} = $pwd."/scripts";	

    dieq error_mess."cannot find data directory: $config->{data_dir}" unless -d $config->{data_dir};	
    dieq error_mess."cannot find scripts directory: $config->{scripts_dir}" unless -d $config->{scripts_dir};	

    &define_table($config);

    if ($config->{mode} eq "NEW") {
	
	if ((defined $config->{h}) ||
	    (!defined $config->{project_name})) {

	    &USAGE($config);
	    die;
	}
	
	# unless ((defined $config->{patient_file}) &&
	# (defined $config->{patho_file}) &&
			# (defined $config->{exome_file})) {
		
		# print &usage_NEW;
	    # die;
	# }
	
	# (defined $config->{pswd}) ?
	# ($config->{pswd} = &get_pswd or dieq error_mess."it seems you don't remember your password") :
	# ($config->{pswd} = &ask_pswd or warnq warn_mess."ok no password");
	
	if (-d $config->{project_name}) {
	
	    if (defined $config->{force_overwrite}) {
	
			rmtree $config->{project_name} or dieq error_mess."cannot remove the directory: $config->{project_name}: $!";
			printq info_mess."$config->{project_name} removed successffully" if defined $config->{verbose};
	    
		} else {
		
		dieq error_mess."$config->{project_name} already exists. Choose an other directory or use the command --force_overwrite";
	    }
	} 
	
	dieq error_mess."cannot create the directory: $config->{project_name}: $!" unless mkdir $config->{project_name};
	dieq error_mess."cannot create the directory: $config->{db_dir}: $!" unless mkdir $config->{db_dir};
    
	} 
    
	elsif ($config->{mode} eq "ALIGN") {
	
	    unless ((defined $config->{project_name}) &&
		    (defined $config->{raw_data}) &&
		    (defined $config->{magic_source})) {

		&USAGE($config);
		die;
	    }
	    
	    $config->{fastc_dir} = $config->{align_dir}."/Fastc";
	    $config->{fastq_dir} = $config->{align_dir}."/Fastq";
	    $config->{target_dir} = $config->{align_dir}."/TARGET";
	    $config->{tmp_align_dir} = $config->{align_dir}."/_tmp";
	    $config->{align_log_dir} = $config->{align_dir}."/Log_files";
	    $config->{runs_ace_file} = $config->{align_dir}."/runs.ace";
	    
	    dieq error_mess."cannot find db file: $config->{db_file}" unless -e $config->{db_file};
	    dieq error_mess."cannot mkdir $config->{align_dir}: $!" unless -d $config->{align_dir} || mkdir $config->{align_dir};
	    dieq error_mess."cannot mkdir $config->{tmp_dir}: $!" unless -d $config->{tmp_align_dir} || mkdir $config->{tmp_align_dir};
	    dieq error_mess."cannot mkdir $config->{align_log_dir}: $!" unless -d $config->{align_log_dir} || mkdir $config->{align_log_dir};
	    dieq error_mess."cannot symlink $config->{raw_data}: $!" unless -d $config->{fastq_dir} || symlink $pwd."/".$config->{raw_data}, $config->{fastq_dir};
	    dieq error_mess."no genome directory defined, you need to define it at least the first time" unless -d $config->{target_dir} || defined $config->{genome};
	    dieq error_mess."cannot symlink $config->{target_data}: $!" unless -d $config->{target_dir} || symlink $pwd."/".$config->{genome}, $config->{target_dir};
	    
	    if ($config->{fastc}) {
		dieq error_mess."cannot symlink $config->{fastc_dir}: $!" unless -d $config->{fastc_dir} || symlink $pwd."/".$config->{fastc}, $config->{fastc_dir};
	    } else {
		dieq error_mess."cannont mkdir $config->{fastc_dir}: $!" unless -d $config->{fastc_dir} || mkdir $config->{fastc_dir};
	    }
	    $ENV{MAGIC_SRC} = $config->{magic_source};
	}
    
    elsif ($config->{mode} eq "ADD") {
	
	if ((defined $config->{h}) ||
	    (!defined $config->{project_name})) {

	    &USAGE($config);
	    die;
	}
	
    } elsif ($config->{mode} eq "CALL") {

	if ((defined $config->{h}) ||
	    (!defined $config->{project_name})) {

	    &USAGE($config);
	    die;
	}

	$config->{snph_dir} = $config->{align_dir}."/tmp/SNPH";
	dieq error_mess."cannot find $config->{snph_dir}: $!" unless -d $config->{snph_dir};

    } elsif ($config->{mode} eq "ANNOT") {
	
	if ((defined $config->{h}) ||
	    (!defined $config->{project_name})) {
	    
	    &USAGE($config);
	    die;
	}

	$config->{annot_dir} = $config->{project_name}."/Annotation";

	dieq error_mess."cannot mkdir $config->{annot_dir}: $!" unless -d $config->{annot_dir} || mkdir $config->{annot_dir};
    }
	else {
	dieq error_mess."Unexpected mode: $mode\n".&USAGE($config);
    }
    
    return $config;
}

sub get_option {
    
    my $config = shift;
    
    GetOptions(
	$config,
	'h',                        # print basic usage
	'help',                     # print compelt usage
	'verbose|v',                # print out a bit more info while running
	'quiet|q',                  # print nothing to STDERR
	'project_name=s',           # 
	'patho_file=s',             #
	'exome_file=s',             #
	'patient_file=s',           #
	'genome=s',                 #
	'raw_data=s',               #
	'fastc=s',                  #
	'gff_file=s',               #
	'magic_source=s',           # 
	'backup',
	'process=s',
	'add_exome=s',
	'add_pathology=s',
	'add_patient=s',
	'fork=i',
	'force_overwrite'           # force overwrite of output file if already exists
	) or dieq error_mess."unexpected options, type -h or --help for help";
    
    return 1;
}

sub define_table {

	my $config = shift;
	$config->{table_name}->{pathology} = "Pathology";
	$config->{table_name}->{variant} = "Variant";
	$config->{table_name}->{exome} = "Exome";
	$config->{table_name}->{patient} = "Patient";
	$config->{table_name}->{carry} = "Carry";
	$config->{table_name}->{call} = "Call";
	$config->{table_name}->{gene} = "Gene";
	$config->{table_name}->{transcript_set} = "Transcript_set";
	$config->{table_name}->{transcript} = "Transcript";
	$config->{table_name}->{vep_impact} = "Vep_impact";
	$config->{table_name}->{vep_csq} = "Vep_consequence";
	$config->{table_name}->{overlap} = "Overlap";
	return 1;
}

sub header {
    chomp(my $time = &get_time);
    my $logo =<<END;
        _
       (_)       #------------------------------#
       |=|       #           ExSQLibur          #
       |=|       #------------------------------#
   /|__|_|__|\\  
  (    ( )    )  # created: 
   \\|\\/\\"/\\/|/   # version:
     |  Y  |     # author: Thomas Karaouzene
     |  |  |     # Date : $time
     |  |  |
    _|  |  |
 __/ |  |  |\\
/  \\ |  |  |  \\
   __|  |  |   |
/\\/  |  |  |   |\\
 <   +\\ |  |\\ />  \\
  >   + \\  | LJ    |
        + \\|+  \\  < \\
  (O)      +    |    )
   |             \\  /\\ 
 ( | )   (o)      \\/  )
_\\\\|//__( | )______)_/ 
        \\\\|//        

END
    return $logo;
}

1;

# sub get_pswd {
#     my $pswd;
#     my @try = (1..3);
#     # foreach my $try (@try) {
#     # 	ReadMode 'noecho';
#     # 	print "Enter your password (try $try): ";
#     # 	chomp(my $pswd1 = <STDIN>);
#     # 	print "\n";
#     # 	print "Confirm your password: ";
#     # 	chomp(my $pswd2 = <STDIN>);
#     # 	print "\n";
#     # 	ReadMode(0);
#     # 	chomp $pswd2;
#     # 	if ($pswd1 eq $pswd2) {
#     # 	    $pswd = $pswd1;
#     # 	    last;
#     # 	} else {
#     # 	    my $remaning_try = length @try - $try;
#     # 	    say "error in your password, do it again (remaning $remaning_try shot(s))";
#     # 	}
#     # }
#     # print "\n";
#     return $pswd;
# }
# sub ask_pswd {
#     my $pswd;
#     my @asks = (1..2);
#     say "Are you sure you don't need a password? (y/n)";
#     foreach my $ask (@asks) {
# 	chomp(my $answer = <STDIN>);
# 	if (uc $answer eq "N") {
# 	    $pswd = &get_pswd or dieq error_mess."it seems you don't remember your password";
# 	} elsif (uc $answer eq "Y") {
# 	    say "Are you really sure? someone could steel the Graal from you (y/n)";
# 	} else {
# 	    say "I don't understand your answer: $answer";
# 	    say "n for no (and having a password) or y for yes";	    
# 	}
#     }
#     return $pswd;
# }
