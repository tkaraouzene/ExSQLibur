#!/usr/bin/env perl

package USAGE;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(USAGE);

sub USAGE {

    my $config = shift;

    my $status = 1;

    if ((defined $config->{mode}) &&
	($config->{mode} ne "USAGE")) {

	if ($config->{mode} eq "NEW") {

	    print &usage_new;

	} elsif ($config->{mode} eq "ADD") {

	    print &usage_add;

	} elsif ($config->{mode} eq "ALIGN") {

	    print &usage_align;

	} elsif ($config->{mode} eq "CALL") {

	    print &usage_call;

	} elsif ($config->{mode} eq "ANNOT") {

	    print &usage_annot;
	}
	
    } else {

	print &usage_main;

    }

    return $status;
}


#############
###########

sub usage_main {

    my $usage =<<END;
Usage
    perl ExSQLibur.pl [mode] [arguments]

Modes:

NEW     # Initialise your project                       
ADD     # Add patient, exome project or pathology to you db
ALIGN   # Align your data using MAGIC software
CALL    # Call genotype
ANNOT   # Annotate your variant using Variant Effect Predictor

For more information about the arguments of a mode,
    perl ExSQLibur.pl [your_mode] -h

Basic options:
=============
--h                              # Display basic usage and quit
--help                           # Display complet usage and quit
--project_name [dir]             # Required whatever your mode
--backup                         # Copy your database before modify it
-v | --verbose                   # Print out a bit more info while running
-q | --quiet                     # Print out a bit less info while running


END

return $usage;
}

sub usage_new {
    
    my $usage =<<END;
Usage NEW:
    perl ExSQLibur.pl NEW [arguments]
Basic options
=============
--h                              # Display basic usage and quit
--project_name [dir]             # Required whatever your mode
--force_overwrite                # force overwrite of output file if already exists

Info : 
       --force_overwrite WARNING!!! will delete all your outdir if already exists

END

return $usage;

}

sub usage_add {

    my $usage =<<END;
Usage ADD:
    perl ExSQLibur.pl ADD [arguments]
Basic options
=============
--h                              # Display basic usage and quit
--project_name [dir]             # Required whatever your mode
--add_exome [file]               # path to file containing your exome project info
--add_pathology [file]           # path to file containing your pathology info
--add_pathient [file]            # path to file containing your patient info

END

return $usage;
}

sub usage_align {

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

END

return $usage;

}

sub usage_call {

    my $usage =<<END;

Usage CALL:
    perl ExSQLibur.pl CALL [arguments]


Sorry usage not written yet for this mode


END

return $usage;

}

sub usage_annot {
    
    my $usage =<<END;

Usage ANNOT:

    perl ExSQLibur.pl ANNOT [arguments]

Basic options
=============
--h                              # Display basic usage and quit
--help                           # Display complet usage and quit
-v | --verbose                   # print out a bit more info while running
-q | --quiet                     # print out a bit less info while running
--project_name [dir]             # [required]

END

return $usage;
}
