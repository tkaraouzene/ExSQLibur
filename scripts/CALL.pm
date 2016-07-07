#!/usr/bin/perl

package CALL;

use lib 'scripts';

use strict;
use warnings;

use my_warnings qw(dieq printq warnq warn_mess error_mess info_mess get_day);
use feature qw(say);

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(ALIGN);



sub CALL {

    my $config = shift;
    printq info_mess."Starting..." if $config->{verbose};










    printq info_mess."Finished!" if $config->{verbose};

	return 1;	
}