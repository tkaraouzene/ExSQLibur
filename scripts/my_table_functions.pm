#!/usr/bin/env perl

package my_table_functions;

use strict;
use warnings;

use DBI;
use feature qw(say);
use my_warnings qw(dieq printq warnq warn_mess error_mess info_mess);
use my_file_manager qw(openIN);

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(connect_database create_table insert_values drop_table create_unique_index my_select alter_table update_table begin_commit);

sub connect_database {

    #-----------------------------------------------------#
    #                                                     #
    # Connect to your database (create it if don't exists #
    #                                                     #
    #-----------------------------------------------------#
    #
    # Arguments:
    #
    # $args: hash ref:
    #          .driver = the driver you want to use
    #          .user = user id (usless if driver = SQLite)
    #          .pswd = your password (usless if driver = SQLite)
    #          .db = your db name
    #          .verbose = print more info message
    #
    #-----------------------------------------------------#

    my $args = shift;

    printq info_mess."Starting..." if $args->{verbose};
    
    my $driver   = $args->{driver} or dieq error_mess."no driver specified"; 
    my $userid = $args->{user} || "";
    my $password = $args->{password} || "";
    my $database = $args->{db};
    my $dsn = "DBI:$driver:dbname=$database";
    my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 }) or dieq error_mess.$DBI::errstr;
    
    printq info_mess."Finished..." if $args->{verbose};

    return $dbh;
}

sub create_table {
    
    #-----------------------------------------------#
    #                                               #
    # Apply SQLite CREATE TABLE function to your db #
    #                                               #
    #-----------------------------------------------#
    #
    # Arguments:
    #
    # $dbh: handle returned by DBI->connect();
    # $args: hash ref: format: column_name => column_typer
    #          .col_name = name of your column
    #          .col_type = table type definition
    # $opt: hash ref:
    #          .table_name = name of the table you want to create
    #          .fk = AoH ref: format [{fk1}, ... ,{fkn}] TODO: complete description
    #              
    #-----------------------------------------------#
    
    my ($dbh,$args,$opt) = @_;
    my $status = 1;

    dieq error_mess."no table defined" unless defined $opt->{table};

    &drop_table($dbh,{table => $opt->{table},
		      test_exist => 1}) if $opt->{drop};
    
    printq info_mess."$opt->{table}: creating..." if $opt->{verbose};
    
    my $fields;
    foreach my $k (keys %$args) {
	$fields .= "," if $fields;
	$fields .= $k." ".$args->{$k};
    }
 
    my @fks;
    
    if ($opt->{fk}) {

        foreach my $fk_stmt (@{$opt->{fk}}) {

            my $fk = qq(CONSTRAINT $fk_stmt->{name}
                            FOREIGN KEY ($fk_stmt->{table_fields})
                            REFERENCES $fk_stmt->{ref_table} ($fk_stmt->{ref_table})
                       );

	    push @fks, $fk;
        }
    }

    my $stmt = qq(CREATE TABLE $opt->{table} );
    $stmt .= "(";
    $stmt .= $fields;
    $stmt .= ",".join ",",@fks if @fks;
    $stmt .= ");";
    
    my $rv = $dbh->do($stmt) or dieq error_mess.$DBI::errstr;
    
    printq info_mess."$opt->{table}: created!" if $opt->{verbose};
    return $status;
}


sub update_table {

    #-----------------------------------------#
    #                                         #
    # Apply sqlite UPDATE function to your db #
    #                                         #
    #-----------------------------------------#
    #
    # Arguments:
    #
    # $dbh: handle returned by DBI->connect();
    # $args: hash ref: format: column_name => new_value
    #
    # $opt: hash ref:
    #
    #-----------------------------------------#

    my ($dbh,$args,$opt) = @_;

    dieq "no table defined" unless defined $opt->{table};
    
    my $set;

    while (@{$args->{fields}}) {
    
	
	my $f = shift @{$args->{fields}};
	my $v = shift @{$args->{values}}; 
	
	$set .= ", " if $set;
	$set .= $f." = ".$v;
    } 

    my $stmt = "UPDATE ";
    $stmt .= "OR $args->{or} " if defined $args->{or} and &check_or($args->{or});
    $stmt .= $set;
    $stmt .= ";";

    my $rv = $dbh->do($stmt) or dieq error_mess.$DBI::errstr;
    
    return 1;
}

sub insert_values {

    my ($dbh,$args) = @_;
    
    dieq error_mess."you have to specify a table" unless $args->{table};
    
    warnq warn_mess."$args->{table}: you are not allowed to use this tag, ignored" if $args->{all_values};

    if (defined $args->{csv_file}) {
	
	printq info_mess."$args->{table}: retrieving data from $args->{csv_file}" if $args->{verbose};
	
	warnq warn_mess."$args->{table}: useless use of fileds in csv_file context, ignored" if $args->{fields};
	warnq warn_mess."$args->{table}: useless use of values in csv_file context, ignored" if $args->{values};
	
	my ($fields,$all_values) = read_csv($args->{csv_file});
	
	$args->{fields} = $fields;
	$args->{all_values} = $all_values;
    
    } elsif ($args->{from_hash}) {

        printq info_mess."$args->{table}: retrieving data from hash" if $args->{verbose};
	dieq error_mess."$args->{table}: you have to specify fields to insert" unless $args->{fields};

	
	foreach my $k (keys %{$args->{from_hash}}) {
	    

	    if (ref $args->{from_hash}->{$k} eq "ARRAY") {

		push @{$args->{all_values}}, [$k,@{$args->{from_hash}->{$k}}];

	    } else {

	    push @{$args->{all_values}}, [$k,$args->{from_hash}->{$k}];
	    }
	}

    } else {

	dieq error_mess."$args->{table}: you have to specify fields to insert" unless $args->{fields};
	dieq error_mess."$args->{table}: you have to specify values to insert" unless $args->{values};

	push @{$args->{all_values}}, $args->{values};
    }
    
    my $f = join ",", @{$args->{fields}};
    
    my $nb_done = 0;
    my $nb_tot = @{$args->{all_values}};

    while (my $values = shift @{$args->{all_values}}) {
	
	&begin_commit({dbh => $dbh,
		       done => $nb_done,
		       tot => $nb_tot,
		       remains => scalar @{$args->{all_values}},
		       scale => 500,
		       verbose => $args->{verbose},
		      }) if defined $args->{begin_commit};
	
	@$values = map {"'$_'"} @$values;
    	my $v = join ",", @$values;
	my $stmt = qq(INSERT INTO $args->{table} ($f) VALUES ($v));   
   	my $rv = $dbh->do($stmt) or dieq error_mess.$DBI::errstr;
	$nb_done++;
    }

    $dbh->commit() if defined $args->{begin_commit};

    return 1;
}

sub begin_commit {

    my $args = shift;

    dieq error_mess."dbh must be specify" unless defined $args->{dbh};
    dieq error_mess."nb done must be specify" unless defined $args->{done};

    $args->{scale} ||= 500;

    my $dbh = $args->{dbh};

    if ($args->{done} % $args->{scale} == 0) {
	
	unless ($args->{done} == 0) {
	    
	    $dbh->commit();

	    my $mess;
	    $mess = $args->{done};
	    $mess .= " / ".$args->{tot} if defined $args->{tot};
	    $mess .= " done";
	    $mess .= " $args->{remains} remaining" if defined $args->{remains};
	    
	    printq info_mess.$mess
	}

	$dbh->begin_work();
    }
    
    return 1;
}

sub create_unique_index {

    my ($dbh,$args) = @_; 
    
    my $stmt = qq(CREATE INDEX $args->{index_name}
                   ON $args->{table} ($args->{fields});
                  );

    my $rv = $dbh->do($stmt) or dieq error_mess.$DBI::errstr;
    
    return 1;
}

sub my_select {

    my ($dbh,$args) = @_;
    my $select = join(",", @{$args->{select}}) || "*";
    my $stmt = qq(SELECT $select FROM $args->{table});

    if (@{$args->{fields}}) {
	
	dieq error_mess."\"fields\" and \"values\" have to contain the same number of values" unless @{$args->{fields}} == @{$args->{values}};
	
	$args->{operator} ||= "AND";

	my @constraints;
	
	foreach my $i (0..$#{$args->{fields}}) {
	    my $f = $args->{fields}->[$i];
	    my $v = $args->{values}->[$i];
	    push @constraints, $f."="."\'".$v."\'";
	}

	my $c = join " ".$args->{operator}." ",@constraints;

	$stmt .= " WHERE ".$c.";";
    }

    my $sth = $dbh->prepare($stmt);
    my $rv = $sth->execute() or die $DBI::errstr;
    my @r = $sth->fetchrow_array();

    (@r >= 1) ?
	((@r == 1) ? (return $r[0]) : (return @r)) :
	(return);
}

sub read_csv {

    my $file = shift;
    my $fh = openIN $file;    

    chomp(my $header = <$fh>);
    
    $header =~ s/^#//;

    my $ch = [split /\t/,lc($header)];
    my $all_values;

    while (<$fh>) {
    	chomp;
	
    	my @c = split /\t/;
    	my $values;
	
	push @$values, $c[$_] || "" foreach 0..$#$ch;
	push @$all_values, $values;
    }
    
    close $fh;

    return $ch,$all_values;
}
   

sub alter_table {

    #----------------------------------------------#
    #                                              #
    # apply sqlite ALTER TABLE function to your db #
    #                                              #
    #----------------------------------------------#
    #
    # Arguments:
    #
    # $dbh: handle returned by DBI->connect();
    # $args: hash ref:
    #          .table = table name
    #          .action = ADD or RENAME
    #          .col_name = name of the new column 
    #          .col_type = table type definition 
    #          .old_name = 
    #          .new_name = 
    #
    # For more information:
    #   https://www.sqlite.org/lang_altertable.html
    #
    #----------------------------------------------#

    my ($dbh,$args) = @_;

    dieq error_mess."no table defined" unless defined $args->{table};
    dieq error_mess."no action defined" unless defined $args->{action};

    if (uc $args->{action} eq "ADD") {
    
	dieq error_mess."col_name must be defined in $args->{action} statment" unless defined $args->{col_name};
	dieq error_mess."col_type must be defined in $args->{action} statment" unless defined $args->{col_type};

	my $stmt = qq(ALTER TABLE $args->{table} ADD $args->{col_name} $args->{col_type};);
	my $rv = $dbh->do($stmt) or dieq error_mess.$DBI::errstr;
    
    } elsif (uc $args->{action} eq "RENAME") {

	dieq error_mess."old_name must be defined in $args->{action} statment" unless defined $args->{old_name};
        dieq error_mess."new_name must be defined in $args->{action} statment" unless defined $args->{new_name};
	
        my $stmt = qq(ALTER TABLE $args->{table} RENAME TO $args->{new_name};);
        my $rv = $dbh->do($stmt) or dieq error_mess.$DBI::errstr;

    } else {
	
	dieq error_mess."unexpected action: $args->{action}, need to be one of ADD or RENAME";
    }

    return 1;
}

sub drop_table {

    #---------------------------------------------#
    #                                             #
    # apply sqlite DROP TABLE function to your db #
    #                                             #
    #---------------------------------------------#
    #
    # Arguments:
    #
    # $dbh: handle returned by DBI->connect();
    # $args: hash ref:
    #          .table = table name
    #          .test_exist = apply "IF EXISTS" test
    #
    # For more information:
    #   http://www.tutorialspoint.com/sqlite/sqlite_drop_table.htm
    #
    #---------------------------------------------#

    my ($dbh,$args) = @_;

    dieq error_mess."no table defined" unless defined $args->{table};

    my $stmt = qq(DROP TABLE);
    $stmt .= " IF EXISTS" if defined $args->{test_exist};
    $stmt .= " ".$args->{table}.");";

    my $rv = $dbh->do($stmt) or dieq error_mess.$DBI::errstr;

    return 1;
}


sub check_or {

    my $or = shift;
    my $status = 1;

    my $good_or = {
	rollback => 1,
	abort => 1,
	replace => 1,
	fail => 1,
	ignore =>1,
    };
	
    unless (defined $good_or->{lc $or}) {
	
	dieq error_mess."unexpected \"OR\" stmt: $or";
	$status = undef;
    }
    
    return $status;
}

sub where_clause {










}
