#==========================================================
# SupportSQL Module - http://supportsql.com/
# Project: PerlMyAdmin
# Module:  WO::MySQL.pm
# Author:  Paul Wilson
# $Id:     MySQL.pm,v 1.00 2002/06/11 15:35:28 paul Exp $
#
# Copyright (c) 2002, SupportSQL.  All Rights Reserved.
#==========================================================
# Description:
# Main SQL module.
#==========================================================

  package WO::MySQL;
#==========================================================

  use strict;
  use MyAdmin::Config;
  use vars qw/$ERRORS $VERSION $ATTR/;

  $VERSION = sprintf "%d.%03d", q$Revision: 1.00 $ =~ /(\d+)\.(\d+)/;
  $ATTR    = {  
                debug  => $CFG->{debug},
                dbh    => undef, 
                dbse   => undef, 
                driver => q$mysql$,
                user   => undef, 
                pass   => undef
  };
  $ERRORS  = { 'NODBI'   => qq|Unable to load DBI.pm. Reason: %s|,
	         'NODRV'   => qq|Unable to load database driver (%s). Available drivers: %s|,
               'PREPARE' => qq|Unable to prepare query:<br><br><font color="#C00000"><b>%s</b></font><br><br>Reason: %s.|,
               'EXECUTE' => qq|Unable to execute query:<br><br><font color="#C00000"><b>%s</b></font><br><br>Reason: %s.|
  };

#==========================================================

sub new {
#----------------------------------------------------------
# Create a new $DB object.

    return bless ($ATTR, $_[0]);
}


sub connect {
#----------------------------------------------------------
# Initialize a new database handle.

    my $self = shift;
    my $opts = shift;

# Load DBI or quit.
    eval { require DBI; }; $@ and die( sprintf($ERRORS->{NODBI}, $@) );

# Make sure our driver is available.
    my @drivers = map { uc } DBI->available_drivers;
    unless (grep { /^\QMYSQL\E$/ } @drivers) {
	    die( sprintf( $ERRORS->{NODRV}, 'MYSQL', join(", ",@drivers ) ) );
    }

# Create a new handle or return the error.
    $self->{dbh} = DBI->connect("DBI:mysql:$opts->{dbse}:$opts->{host}", $opts->{user}, $opts->{pass}) || DBI->errstr;

    return;
}

sub show_db {
#----------------------------------------------------------
# Returns a list of all databases for this host.

    my $self = shift;
    my $que  = 'SHOW DATABASES';
    my $ref  = $self->prepare($que, 'FETCHALL_ARRAYREF');

    return ( ref $ref eq 'ARRAY' ? map { $_->[0] } @$ref : () );
}

sub show_vars {
#----------------------------------------------------------
# Returns a list of variables.

    my $self = shift;
    my $que  = 'SHOW VARIABLES';
    my $ref  = $self->prepare($que, 'FETCHALL_ARRAYREF');
    
    return ( ref $ref eq 'ARRAY' ? @$ref : () );
}

sub show_keys {
#----------------------------------------------------------
# Returns a list of keys for the table.

    my $self = shift;
    my $tab  = shift;
    my $db   = shift;
    my $que  = 'SHOW INDEX FROM ' . $tab . ' FROM ' . $db;
    my $ref  = $self->prepare($que, 'FETCHALL_ARRAYREF');
    
    return ( ref $ref eq 'ARRAY' ? $ref : [] );
}

sub show_status {
#----------------------------------------------------------
# Returns a list of status vars.

    my $self = shift;
    my $que  = 'SHOW STATUS';
    my $ref  = $self->prepare($que, 'FETCHALL_ARRAYREF');

    return ( ref $ref eq 'ARRAY' ? @$ref : () );
}

sub show_grants {
#----------------------------------------------------------
# Show grants for a user.

    my $self = shift;
    my $user = shift;
    my $host = shift;
    my $que  = "SHOW GRANTS FOR $user\@$host";
    my $res  = $self->prepare($que, 'FETCHROW');

    return ( $res );
}

sub drop_db {
#----------------------------------------------------------
# Drop a database.

    my $self = shift;
    my $db   = shift;
    my $que  = 'DROP DATABASE ' . $db;
    
    $self->prepare($que, 'FETCHROW');

    return;
}

sub drop_index {
#----------------------------------------------------------
# Drop a key.

    my $self = shift;
    my $tab  = shift;
    my $ndx  = shift;
    my $que  = 'ALTER TABLE ' . $tab . ' DROP ';
    
# Is this a primary key or not?
    $que .= $ndx eq 'PRIMARY' ? 'PRIMARY KEY' : 'INDEX ' . $ndx;
    
    $self->prepare($que, 'FETCHROW');

    return;
}

sub drop_col {
#----------------------------------------------------------
# Drop a column.

    my $self = shift;
    my $tab  = shift;
    my $col  = shift;
    my $que  = 'ALTER TABLE ' . $tab . ' DROP ' . $col;
    
    $self->prepare($que, 'FETCHROW');

    return;
}

sub get_col {
#----------------------------------------------------------
# Retun the attributes for the requested column.

    my $self = shift;
    my $tab  = shift;
    my $col  = shift;
    my $que  = 'DESCRIBE ' . $tab . ' ' . $col;
    my $attr = $self->prepare($que, 'FETCHROW_HASHREF');

    return ( ref $attr eq 'HASH' ? $attr : {} );
}

sub create_db {
#----------------------------------------------------------
# Create a database.

    my $self = shift;
    my $db   = shift;
    my $que  = 'CREATE DATABASE ' . $db;
    
    $self->prepare($que, 'FETCHROW');

    return;
}

sub load_db {
#----------------------------------------------------------
# Return the tables within the database.

    my $self = shift;
    my $que  = 'SHOW TABLES';
    my $ref  = $self->prepare($que, 'FETCHALL_ARRAYREF');

    return ( ref $ref eq 'ARRAY' ? $ref : [] );
}

sub process_db {
#----------------------------------------------------------
# Return the tables within the database.

    my $self = shift;
    my $que  = 'SHOW PROCESSLIST';
    my $ref  = $self->prepare($que, 'FETCHALL_ARRAYREF');

    return ( ref $ref eq 'ARRAY' ? @$ref : () );
}

sub edit_row {
#----------------------------------------------------------
# Edit an individual row.

    my $self = shift;
    my $que  = shift;
    
    $self->prepare($que, 'FETCHROW');

    return;
}

sub drop_table {
#----------------------------------------------------------
# Drop a table.

    my $self = shift;
    my $tab  = shift;
    my $que  = 'DROP TABLE ' . $tab;
    
    $self->prepare($que, 'FETCHROW');

    return;
}

sub rename_table {
#----------------------------------------------------------
# Rename a table.

    my $self = shift;
    my $tab  = shift;
    my $new  = shift;
    my $que  = 'RENAME TABLE ' . $tab . ' TO ' . $new;
    
    $self->prepare($que, 'FETCHROW');

    return;
}

sub empty_table {
#----------------------------------------------------------
# Empty a table.

    my $self = shift;
    my $tab  = shift;
    my $que  = 'DELETE FROM ' . $tab;
    
    $self->prepare($que, 'FETCHROW');

    return;
}

sub stats_table {
#----------------------------------------------------------
# Show some table stats.

    my $self = shift;
    my $tab  = shift;
    my $que  = 'SHOW TABLE STATUS';
    my $ref  = $self->prepare($que, 'FETCHALL_ARRAYREF');

# Return the hashrefs we want.
    if (ref $ref eq 'ARRAY') {
        foreach my $want (@{$ref}) {
            if ($want->[0] eq $tab) {
                return $want;
            }
            next;
        }
    }

    return [];
}

sub attr_table {
#----------------------------------------------------------
# Describe a table.

    my $self = shift;
    my $tab  = shift;
    my $que  = 'DESCRIBE ' . $tab;
    my $ref  = $self->prepare($que, 'FETCHALL_ARRAYREF');

    return ( ref $ref eq 'ARRAY' ? $ref : [] );
}

sub add_primary_key {
#----------------------------------------------------------
# Add a primary key.

    my $self = shift;
    my $tab  = shift;
    my $col  = shift;
    my $que  = 'ALTER TABLE ' . $tab . ' ADD PRIMARY KEY (' . $col . ')';
    
    $self->prepare($que, 'FETCHALL_ARRAYREF');

    return;
}

sub add_unique_key {
#----------------------------------------------------------
# Make the column unique.

    my $self = shift;
    my $tab  = shift;
    my $col  = shift;
    my $que  = 'ALTER TABLE ' . $tab . ' ADD UNIQUE (' . $col . ')';
    
    $self->prepare($que, 'FETCHALL_ARRAYREF');

    return;
}

sub add_index_key {
#----------------------------------------------------------
# Add an index.

    my $self = shift;
    my $tab  = shift;
    my $col  = shift;
    my $que  = 'ALTER TABLE ' . $tab . ' ADD INDEX (' . $col . ')';
    
    $self->prepare($que, 'FETCHALL_ARRAYREF');

    return;
}

sub delete_row {
#----------------------------------------------------------
# Delete a table row.

    my $self = shift;
    my $tab  = shift;
    my $whe  = shift;
    my $que  = 'DELETE FROM ' . $tab . ' WHERE ' . $whe . ' LIMIT 1';
    my $ref  = $self->prepare($que, 'FETCHROW');

    return;
}

sub insert_row {
#----------------------------------------------------------
# Insert a new row.

    my $self = shift;
    my $que  = shift;
    
    $self->prepare($que, 'FETCHROW');

    return;
}

sub create_table {
#----------------------------------------------------------
# Create a table. Accepts an arrayref of hashrefs.

    my $self = shift;
    my $col  = shift;
    my $tab  = shift;
    my $pri  = join (', ', map { $_->{field} } grep defined $_->{primary}, @$col);
    my $ind  = join (', ', map { $_->{field} } grep defined $_->{index},   @$col);
    my $uni  = join (', ', map { $_->{field} } grep defined $_->{unique},  @$col);
    my $que  = 'CREATE TABLE ' . $tab . ' ( ';
    my $ref;
    
# Loops the cols and build the query.
    foreach my $spec (@$col) {
        $que .= $spec->{field} . ' ';
        $que .= $spec->{type};
        $que .= '(' . $spec->{set} . ')' if $spec->{set};
        $que .= ' ' .$spec->{attr}  . ' ';
        $que .= $spec->{null}  . ' ';
        $que .= 'DEFAULT '    . $self->{dbh}->quote($spec->{default}) . ' ';
        $que .= $spec->{extra} . ', ';
    }

# Stip trailing commans and spaces.
    $que =~ s/[\s,]+$//;

# Deal with keys.
    $que .= ", PRIMARY KEY ($pri)" if $pri;
    $que .= ", INDEX ($ind)"       if $ind;
    $que .= ", UNIQUE ($uni)"      if $uni;
    $que .= ' )';

    $self->prepare($que, 'FETCHROW');

    return;
}

sub add_cols {
#----------------------------------------------------------
# Add cols to a table. This and create_table are similar but seperate for clarity.

    my $self = shift;
    my $col  = shift;
    my $tab  = shift;
    my $pos  = shift;
    my $pri  = join (', ', map { $_->{field} } grep defined $_->{primary}, @$col);
    my $ind  = join (', ', map { $_->{field} } grep defined $_->{index},   @$col);
    my $uni  = join (', ', map { $_->{field} } grep defined $_->{unique},  @$col);
    my $que  = 'ALTER TABLE ' . $tab;
    my $ref;
    
# Loops the cols and build the query.
    foreach my $spec (@$col) {
        $que .= ' ADD ';
        $que .= $spec->{field} . ' ';
        $que .= $spec->{type};
        $que .= '(' . $spec->{set} . ')' if $spec->{set};
        $que .= ' ' .$spec->{attr}  . ' ';
        $que .= $spec->{null}  . ' ';
        $que .= 'DEFAULT '    . $self->{dbh}->quote($spec->{default}) . ' ';
        $que .= $spec->{extra} . ' ' . $pos . ', ';
        $pos  = ' AFTER ' . $spec->{field};
    }

# Stip trailing commans and spaces.
    $que =~ s/[\s,]+$//;

# Deal with keys.
    $que .= ", ADD PRIMARY KEY ($pri)" if $pri;
    $que .= ", ADD INDEX ($ind)"       if $ind;
    $que .= ", ADD UNIQUE ($uni)"      if $uni;

    $self->prepare($que, 'FETCHROW');

    return;
}

sub alter_col {
#----------------------------------------------------------
# Alter a column when given a hashref of attributes and a table.

    my $self = shift;
    my $col  = shift;
    my $tab  = shift;
    my $name = shift;
    my $que  = 'ALTER TABLE ' . $tab . ' CHANGE ' . $name . ' ';
    
# Build the query.
    $que .= $col->{field} . ' ';
    $que .= $col->{type};
    $que .= '(' . $col->{set} . ')' if $col->{set};
    $que .= ' ' .$col->{attr}  . ' ';
    $que .= $col->{null}  . ' ';
    $que .= 'DEFAULT '    . $self->{dbh}->quote($col->{default}) . ' ';
    $que .= $col->{extra} . ', ';

# Stip trailing commans and spaces.
    $que =~ s/[\s,]+$//;

    $self->prepare($que, 'FETCHROW');

    return;
}

sub rows {
#----------------------------------------------------------
# Return the number of rows in a table.

    my $self = shift;
    my $tab  = shift;
    my $que  = 'SELECT COUNT(*) FROM ' . $tab;
    my $ref  = $self->prepare($que, 'FETCHROW');

    return ( $ref =~ /^\d+$/ ? $ref : 0 );
}

sub dump_table {
#----------------------------------------------------------
# Dump a table and its data if desired.

    my $self   = shift;
    my $db     = shift;
    my $table  = shift;
    my $create = shift;
    my $insert = shift;
    my $drop   = shift;
    my $del    = shift;
    my $com    = shift;
    my $mul    = shift;
    my $que    = '';
    my @tmp    = ();
    my $tmp;

# Only dump the table structure if requested.
    if ($create) {
        $que .= "#" . ("=" x 75) . "\n";
        $que .= "# Dumping structure for table '$table'\n";
        $que .= "#" . ("=" x 75) . "\n";
        $que .= "\nDROP TABLE IF EXISTS $table;\n" if $drop;
        $que .= "\nCREATE TABLE " . $table . "(\n  ";

# Let's get the table attribs.
        my $attr = $self->attr_table($table);

# Loops the cols and build the query.
        foreach my $spec (@$attr) {
            $que .= $spec->[0] . ' ' . $spec->[1] . ' ';
            $que .= $spec->[2] ? 'NULL ' : 'NOT NULL ';
            $que .= 'DEFAULT ' . $self->{dbh}->quote($spec->[4]) . ' ';
            $que .= $spec->[5] . ",\n  ";
        }

# Deal with keys. Sigh.
        $que .= $self->parse_keys($table);

# Stip trailing commans and spaces.
        $que =~ s/[\s,]+$//;

        $que .= "\n);\n\n";
    }

# Now do inserts. We use a different prepare routine so we can loop the sth.
    if ($insert) {
        $que .= "#" . ("=" x 75) . "\n";
        $que .= "# Dumping data for table '$table'\n";
        $que .= "#" . ("=" x 75) . "\n\n";
        my $sth  = $self->prepare_sth("SELECT * FROM $table");
        my $attr = $self->attr_table($table);
        if ($mul) {
            $tmp .= "INSERT ";
            $tmp .= "DELAYED " if $del;
            $tmp .= "INTO $table ";
            $tmp .= "(" . join(',', map { $_->[0] } @$attr ) . ") " if $com;
            $tmp .= "VALUES ";
        }
        while (my @row = $sth->fetchrow) {
            if (! $mul) {
                $que .= "INSERT ";
                $que .= "DELAYED " if $del;
                $que .= "INTO $table ";
                $que .= "(" . join(',', map { $_->[0] } @$attr ) . ") " if $com;
                $que .= "VALUES ";
                $que .= "(" . join(',', map { $self->{dbh}->quote($_) } @row) . ")";
                $que .= ";\n";
            }
            else {
                push @tmp,  "(" . join(',', map { $self->{dbh}->quote($_) } @row) . ")";
            }
        }

# Strip the trailing comma and start a new line.
        if ($mul and scalar @tmp) {
            $que .= $tmp . join(',', @tmp);
            $que .= ";\n";
        }       
        $que .= "\n";

# Close the staement handle.
        $sth->finish if defined $sth;
    }

    return $que;
}

sub parse_keys {
#----------------------------------------------------------
# Append any keys to the create table command.

    my $self  = shift;
    my $table = shift;
    my $sth   = $self->prepare_sth("SHOW KEYS FROM $table");
    my $out   = '';
    my $name  = '';
    my @key   = ();
    my ($ckn, $nu, $cnu, $spec);
       
    while (my @keys = $sth->fetchrow) {
           my $cnu = $keys[1];
           my $ckn = $keys[2];
           my $col = $keys[4];
            
           if ($name eq $ckn) { push @key, $col }
           else {
                if ($name) {
                    if    ($name eq 'PRIMARY') { $out .= "PRIMARY KEY"  }
                    elsif ($nu)                { $out .= "KEY $name "   }
                    else                       { $out .= "UNIQUE $name" }
                    $out .= "(" . join("," , @key) . "),\n  ";
                 }

# Reset the keys array for the next set of keys.
                 @key = ();
                 push @key, $col;
                 $name = $ckn; 
                 $nu   = $cnu;
           }
    }
    $sth->finish if defined $sth;

    if ($name) {
        if    ($name eq 'PRIMARY') { $out .= "PRIMARY KEY "  }
        elsif ($nu)                { $out .= "KEY $name "    }
        else                       { $out .= "UNIQUE $name " }
        $out .= "(" . join("," , @key) . "),\n  ";
    }

    return $out;
}

sub prepare {
#----------------------------------------------------------
# Prepare and execute a query. Accepts a query and a DBI method as an arg.

    my $self = shift;
    my $que  = shift;
    my $meth = lc shift;
    my $flag = undef;
    my $call = caller(1); # Will (should) only be MyAdmin::Functions
    my $sth  = $self->{dbh}->prepare($que) or $flag .= sprintf($ERRORS->{PREPARE}, $que, DBI->errstr); 
               $sth->execute               or $flag .= sprintf($ERRORS->{EXECUTE}, $que, DBI->errstr);

# Do some error handling.
    if (defined $flag) {
        return $call->sql_error($flag);
    }

# Call thedesired method if there wasn't an error.
    my @out = $sth->$meth;

# Finish.
    $sth->finish;

    return $out[0..$#out]; # List context.
}

sub export_data {
#----------------------------------------------------------
# Export a table.

    my ($self, $path, $table, $join, $rsep, $fsep, $esc) = @_;

# Properly quote.
    $path = $self->{dbh}->quote($path);
    $esc  = $self->{dbh}->quote($esc);
    $fsep = "'"  . $fsep . "'";
    $rsep =  "'" . $rsep . "'";

    my ($query) = "SELECT $join INTO OUTFILE $path FIELDS TERMINATED BY $fsep ESCAPED BY $esc LINES TERMINATED BY $rsep FROM $table";

    $self->prepare($query, 'FETCHROW');

    return;
}

sub import_data {
#----------------------------------------------------------
# Import table data.

    my ($self, $path, $table, $join, $rsep, $fsep, $esc, $skip, $ow) = @_;
    my ($query) = '';

# Properly quote.
    $path = $self->{dbh}->quote($path);
    $esc  = $self->{dbh}->quote($esc);
    $fsep = "'"  . $fsep . "'";
    $rsep =  "'" . $rsep . "'";
    $skip = 0 unless $skip =~ /^\d+$/;

    $query .= "LOAD DATA INFILE $path $ow INTO TABLE $table FIELDS TERMINATED BY $fsep ";
    $query .= "ESCAPED BY $esc LINES TERMINATED BY $rsep IGNORE $skip LINES";

# Selected columns, if any.
    $query .= " $join" unless ($join eq '*');

    $self->prepare($query, 'FETCHROW');

    return;
}

sub load_users {
#----------------------------------------------------------
# Load all users for this host.

    my $self = shift;
    my $cols = $_[0] eq '*' ? '*' : join(',', @_);
    my $q    = "SELECT $cols FROM user";
    my $ref  = $self->prepare($q, 'FETCHALL_ARRAYREF');

    return ( $ref );
}

sub prepare_sth {
#----------------------------------------------------------
# Prepare and execute a query but return a statement handle.

    my $self = shift;
    my $que  = shift;
    my $flag = undef;
    my $call = caller(1); # Will (should) only be MyAdmin::Functions
    my $sth  = $self->{dbh}->prepare($que) or $flag .= sprintf($ERRORS->{PREPARE}, $que, DBI->errstr); 
               $sth->execute               or $flag .= sprintf($ERRORS->{EXECUTE}, $que, DBI->errstr . DBI->err);

# Do some error handling.
    if (defined $flag) {
        return $call->sql_error($flag);
    }

    return $sth;
}

sub escape {
#----------------------------------------------------------
# Escape a field.
 
    my ($self, $field, $del) = @_;
    $field =~ s/(\Q$del\E)/\\$1/g;
    return ( $field );
}

sub DESTROY {
#----------------------------------------------------------
# DESTROY is called at the end of execution.

# Disconnect.
    $_[0]->{dbh}->disconnect if ref $_[0]->{dbh};
    $_[0]->{dbh} = undef;
}

1;
