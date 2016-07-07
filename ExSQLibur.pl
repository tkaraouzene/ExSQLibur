#!/usr/bin/perl
use lib 'scripts';
use strict;
use warnings;
use my_warnings qw(get_time dieq printq warnq warn_mess error_mess info_mess);
use Getopt::Long;
# use Term::ReadKey;
use feature qw(say);
use File::Path qw(rmtree);
use NEW qw(NEW);
use ALIGN qw(ALIGN);
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
    if ($config->{mode} eq "NEW") {
	&NEW($config);
    } elsif ($config->{mode} eq "ALIGN") {
	&ALIGN($config);
    }  elsif ($config->{mode} eq "ADD") {
	&ADD($config);
	} else {
	dieq error_mess."Unexpected mode: $config->{mode}".&usage;
    }
    printq info_mess."Finished!" unless $config->{quiet};
}

sub configure {

	# sets up configuration hash that is used throughout the script
	
    my @ARGV_copy = @ARGV;
    my $args = shift;
    my $mode = shift @$args || "";   
    my $config = {};
    
	$config->{mode} = $mode;
	
	get_option($config);
	
    unless ((defined $config->{mode}) || 
	    ($config->{mode} ne "NEW")) {	
	print &usage;
	die;
    }
    if((defined $config->{h}) || !$args) {
	print &usage;
	die;
    }
	
	chomp(my $pwd = `pwd`);

	$config->{project_name} =~ s/\/$//;
    $config->{db_dir} = $config->{project_name}."/DB";
    $config->{db} = $config->{db_dir}."/".$config->{project_name};
    $config->{db_file} = $config->{db}.".db";
    $config->{align_dir} = $config->{project_name}."/Align_data";
	$config->{data_dir} = $pwd."/data";	
	$config->{scripts_dir} = $pwd."/scripts";	

	dieq error_mess."cannot find data directory: $config->{data_dir}" unless -d $config->{data_dir};	
	dieq error_mess."cannot find scripts directory: $config->{scripts_dir}" unless -d $config->{scripts_dir};	

	define_table($config);

    if ($config->{mode} eq "NEW") {
	
	unless ((defined $config->{project_name}) &&
			(defined $config->{patient_file}) &&
			(defined $config->{patho_file}) &&
			(defined $config->{exome_file})) {
		
		print &usage_NEW;
	    die;
	}
	
	# (defined $config->{pswd}) ?
	# ($config->{pswd} = &get_pswd or dieq error_mess."it seems you don't remember your password") :
	# ($config->{pswd} = &ask_pswd or warnq warn_mess."ok no password");
	
	dieq error_mess."Cannot find --patient_file $config->{patient_file}" unless -e $config->{patient_file};
	dieq error_mess."Cannot find --patho_file $config->{patho_file}" unless -e $config->{patho_file};
	dieq error_mess."Cannot find --exome_file $config->{exome_file}" unless -e $config->{exome_file};
	
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
			print &usage_ALIGN;
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
	
    else {
	dieq error_mess."Unexpected mode: $mode\n".&usage;
    }
   
   return $config;
}

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

sub get_option {
	
	my $config = shift;
	
	GetOptions(
		$config,
		'h',                        # print basic usage
		'help',                     # print compelt usage
		'verbose|v',                # print out a bit more info while running
		'quiet|q',                  # print nothing to STDERR
		'project_name=s',           # 
		'user=s',                   #
		'pswd',                     #
		'patho_file=s',             #
		'exome_file=s',             #
		'patient_file=s',           #
		'genome=s',                 #
		'raw_data=s',               #
		'fastc=s',                  #
		'gff_file=s',               #
		'magic_source=s',           # 
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

sub usage {

    my $usage =<<END;
Usage
    perl ExSQLibur.pl [mode] [arguments]
Modes:
NEW                              #                       
For more information about the arguments of a mode,
    perl ExSQLibur.pl your_mode -h
END
return $usage;
}

sub usage_NEW {
    my $usage =<<END;
Usage NEW:
    perl ExSQLibur.pl NEW [arguments]
Basic options
=============
--h                              # Display basic usage and quit
--help                           # Display complet usage and quit
-v | --verbose                   # print out a bit more info while running
-q | --quiet                     # print out a bit less info while running
--project_name [dir]             # [required]
--user                           # [required]
--patient_file                   # [required]
--patho_file                     # [required]
--exome_file                     # [required]
--pswd                           #
--force_overwrite                # force overwrite of output file if already exists
Info : 
       --force_overwrite WARNING!!! will delete all your outdir if already exists
END
return $usage;
}

sub usage_ALIGN {
    my $usage =<<END;
Usage ALIGN:
    perl ExSQLibur.pl ALIGN [arguments]
Basic options
=============
--h                              # Display basic usage and quit
--help                           # Display complet usage and quit
-v | --verbose                   # print out a bit more info while running
-q | --quiet                     # print out a bit less info while running
--project_name [dir]             # [required]
--raw_data [dir]                 # [required] directory containing all raw data you want to align
--fastc [dir]                    # directory containing fastc data
--genome [dir]                   # directory containing human reference genome
--magic_source [dir]             # directory containing human reference genome
--user                           # [required]
--pswd                           #
Info : 
       --force_overwrite WARNING!!! will delete all your outdir if already exists
END
return $usage;
}

sub header {
    chomp(my $time = &get_time);
    my $logo =<<END;
        _
       (_)       #------------------------------#
       |=|       #           ExSQLibur          #
       |=|       #------------------------------#
   /|__|_|__|\  
  (    ( )    )  # created: 
   \|\/\"/\/|/   # version:
     |  Y  |     # author: Thomas Karaouzene
     |  |  |     # Date : $time
     |  |  |
    _|  |  |
 __/ |  |  |\
/  \ |  |  |  \
   __|  |  |   |
/\/  |  |  |   |\
 <   +\ |  |\ />  \
  >   + \  | LJ    |
        + \|+  \  < \
  (O)      +    |    )
   |             \  /\ 
 ( | )   (o)      \/  )
_\\|//__( | )______)_/ 
        \\|//        
END
    return $logo;
}