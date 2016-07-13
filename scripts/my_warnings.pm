#!/usr/bin/env perl

package my_warnings;
require Exporter ;

use strict;
use warnings;

our @ISA = qw(Exporter) ;
our @EXPORT_OK = qw(printq warnq dieq get_day get_time error_mess info_mess warn_mess) ;

sub get_time {
    my @time = localtime(time());

    # increment the month (Jan = 0)
    $time[4]++;

    # add leading zeroes as required
    for my $i(0..4) {
        $time[$i] = "0".$time[$i] if $time[$i] < 10;
    }

    # put the components together in a string
    my $time =
        ($time[5] + 1900)."-".
        $time[4]."-".
        $time[3]." ".
        $time[2].":".
        $time[1].":".
        $time[0];

    return $time;
}

sub get_day {

    my @day = localtime(time());

    # increment the month (Jan = 0)
    $day[4]++;

    # add leading zeroes as required
    for my $i(3..4) {
        $day[$i] = "0".$day[$i] if $day[$i] < 10;
    }

    # put the components together in a string
    my $day =
        ($day[5] + 1900)."-".
        $day[4]."-".
	$day[3];
	
    return $day;

}

# prints warn output in STDERR with time
sub warnq {

    my $text = (@_ ? (join "", @_) : "No message");
    my $time = &get_time;
    
    warn $time." - ".$text.($text =~ /\n$/ ? "" : "\n");
}

# prints output in STDOUT with time
sub printq {

    my $text = (@_ ? (join "", @_) : "No message");
    my $time = &get_time;
    
    ($text =~ /^$/) ? (print $time."\n") : (print $time." - ".$text.($text =~ /\n$/ ? "" : "\n"));

}

# print die output in STDERR with time
sub dieq {
    
    my $text = (@_ ? (join "", @_) : "No message");
    my $time = &get_time;
    
    ($text =~ /^$/) ? (die $time."\n") : (die $time." - ".$text.($text =~ /\n$/ ? "" : "\n"));
}

sub error_mess {

    my $from = ( caller(1) )[3] || "main";

    my $error_mess = "error: (".$from."): ";
    return $error_mess;    
}

sub info_mess {

    my $from = ( caller(1) )[3] || "main";
    
    my $error_mess = "INFO: (".$from."): ";
    return $error_mess;    
}

sub warn_mess {

    my $from = ( caller(1) )[3] || "main";

    my $warn_mess = "WARNING!: (".$from."): ";
    return $warn_mess;    
}

sub fork_out_error { 

    my ($pid, $exit_code) = @_;
    dieq error_mess."fill hash talbes: **  just got out of the pool ".
	"with PID $pid and exit code: $exit_code\n" unless $exit_code == 0;
    return;
}
