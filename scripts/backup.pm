#!/usr/bin/perl

package backup;

use lib 'mylib';

use strict;
use warnings;

use File::Copy::Recursive qw(rcopy);
use my_warnings qw(dieq printq warnq warn_mess error_mess info_mess get_day);

use feature qw(say);

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(backup);

sub backup {

    my $config = shift;
    my $status = 1;
    
    printq info_mess."Starting..." unless defined $config->{quiet};

    dieq error_mess."cannot mkdir $config->{backup_dir}: $!" unless -d $config->{backup_dir} or mkdir $config->{backup_dir};

    my $back_dir = $config->{backup_dir}."/".get_day();
    my $i = 1;

    while (-d $back_dir) {
	$i++;
	$back_dir = $config->{backup_dir}."/".get_day()."_".$i;
    }
    
    dieq error_mess."cannot mkdir $back_dir: $!" unless -d $back_dir || mkdir $back_dir;

    opendir(my $dh, $config->{project_name}) || dieq error_mess"Can't opendir $config->{project_name}: $!";
    while (my $d = readdir $dh) {
	
	next if $d eq "." or $d eq "..";
	next if $config->{project_name}."/".$d eq $config->{backup_dir};

	rcopy($config->{project_name}."/".$d,$back_dir."/".$d) or dieq error_mess."cannot copy $config->{project_name}/$d to $back_dir: $!";
    }
    closedir $dh;

    printq info_mess."Finished!" unless defined $config->{quiet};
    return $status;
}
