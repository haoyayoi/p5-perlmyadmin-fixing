#==========================================================
# SupportSQL Module - http://supportsql.com/
# Project: PerlMyAdmin
# Module:  MyAdmin::Functions
# Author:  Paul Wilson
# $Id:     Functions.pm,v 1.00 2002/08/20 00:50:34 paul Exp $
#
# Copyright (c) 2002, SupportSQL.  All Rights Reserved.
#==========================================================
# Description:
# Handles all actions.
#==========================================================

  package MyAdmin::Functions;
#==========================================================

  use strict;
  use WO::Base;
  use MyAdmin::Config;
  use vars qw/$ERRORS/;
  use MyAdmin::Objects qw/$IN $DB $TPL/;

  $ERRORS = { 'BADACTION'  => 'The script received an action it did not understand!',
              'LOGOUT'     => 'You have been successfully logged out!',
              'CANTDUMP'   => 'Unable to open dump file for writing:<br><br>File: <font color="#C00000"><b>%s</b></font><br><br>Reason: %s',
              'DUMPFILE'   => 'The dump file you specified is invalid:<br><br>Reason: <font color="#C00000"><b>The file extension must contain alphanumerics and underscores only.</b></font>',
              'SERVERFILE' => 'The file %s  has an invalid filename.',
              'SERVERQ'    => 'Unable to read query file %s. Reason: %s',
              'EXPORTF'    => 'Unable to open export file %s.<br><br>Reason: <font color="#C00000"><b>%s</b></font>',
              'EXPDIR'     => 'Unable to open export directory %s.<br><br>Reason: <font color="#C00000"><b>%s</b></font>',
              'EXPFILE'    => 'The export file you specified is invalid:<br><br>Reason: <font color="#C00000"><b>The file extension must contain alphanumerics and underscores only.</b></font>',
              'IMPORTF'    => 'Unable to open import file %s.<br><br>Reason: <font color="#C00000"><b>%s</b></font>',
              'IMPFILE'    => 'The import file you specified is invalid:<br><br>Reason: <font color="#C00000"><b>The file extension must contain alphanumerics and underscores only.</b></font>',
              'WRONGDB'    => 'The database you specified is incorrect.'
  };

#==========================================================

sub handle {
#----------------------------------------------------------
# Handle all requests and decide what to do.

    my $do    = $CFG->{auto} ? $IN->param('do') ? $IN->param('do') : 'login' : $IN->param('do');
    my $input = MyAdmin::Objects->get_hash;

# Create a database handle if possible.
    if (grep { /^\Q$do\E$/ } @{$CFG->{actions}}) {

        _create_handle();

# Connection problem means no dbh object.
        if (not ref $DB->{dbh}) {
            print $IN->header();
            $TPL->parse('admin_login', { %$input, error => ($do ? $DB->{dbh} : '') } );
            return;
        }
        else {

# Common actions.
            no strict 'refs';
            if (defined &{ $do }) { &{ $do } }

# Unknown action.
            else {
                print $IN->header();
                $TPL->parse('admin_login', { error => $ERRORS->{BADACTION} } );
                return;
            }
        }
    }
    else {
        print $IN->header();
        $TPL->parse('admin_login', 
               { 
                  my_host => scalar $IN->cookie($CFG->{ck_host}), 
                  my_user => scalar $IN->cookie($CFG->{ck_user}) 
               }
        );
        return;
    }
}

sub _create_handle {
#----------------------------------------------------------
# Try to create a database handle. Use pre-defined fields in auto-connecting.

    my $h = $IN->param('host') || $IN->cookie($CFG->{ck_host});
    my $d = $IN->param('db')   || $IN->cookie($CFG->{ck_dbse});
    my $u = $IN->param('user') || $IN->cookie($CFG->{ck_user});
    my $p = $IN->param('pass') || _decrypt($IN->cookie($CFG->{ck_pass}));

# If using auto connect then use the specified values.
    if ($CFG->{auto}) {
        $h = $CFG->{host};
        $d = $CFG->{dbse} if $CFG->{dbse};
        $u = $CFG->{user};
        $p = $CFG->{pass};
    }

# Creates a database handle.
    $DB->connect( { host => $h, dbse => $d, user => $u, pass => $p } );
}

sub dump_db {
#----------------------------------------------------------
# Show the dump page.

    require Cwd;

    my $ref = $DB->load_db();
    my $tmp = [];
    my $cwd = Cwd::cwd();
    my $dat = join('-', (split /\s/, scalar localtime)[1,2,4]);

# Create a template loop.
    if (ref $ref eq 'ARRAY') {
        foreach my $table (@$ref) {
            push @$tmp, { table => $table->[0] };
        }
    }

    print $IN->header();
    $TPL->parse('admin_dump_db', { cwd => $cwd, date => $dat, tab_loop => $tmp, db => scalar $IN->param('db') } );
}

sub show_vars {
#----------------------------------------------------------
# Return a detailed list of variables for the mysql server.

    my $var_loop = [ map +{ var => $_->[0], value => $_->[1]  }, $DB->show_vars ];
    
    print $IN->header();
    $TPL->parse('admin_show_vars', { var_loop => $var_loop } );
}

sub show_dbs {
#----------------------------------------------------------
# Return a formatted list of databases.

# Grab the database names and map them into a loop.
    my $dbs_loop = [ map +{ db => $_ }, $DB->show_db   ];
    my $ver      = [ $DB->show_vars ]->[-2]->[1];
    my $host     = $CFG->{auto} ? $CFG->{host} : $IN->cookie($CFG->{ck_host});

# Only set cookies if the user is logging in.
    print $IN->param('do') eq 'login' ? $IN->header( -cookie => _set_cookies() ) : $IN->header();
    $TPL->parse('admin_db_list', { ver => $ver, host => $host, db_loop => $dbs_loop, dbs => scalar(@$dbs_loop) } );
}

sub show_status {
#----------------------------------------------------------
# Show details status vars.

    my $st_loop = [ map +{ status => $_->[0], value => $_->[1] }, $DB->show_status   ];

    print $IN->header();
    $TPL->parse('admin_status', { st_loop => $st_loop } );
}

sub drop_db {
#----------------------------------------------------------
# Drop a database.

    $DB->drop_db($IN->param('db'));
    show_dbs();
}

sub create_db {
#----------------------------------------------------------
# Create a database page.

    print $IN->header();
    $TPL->parse('admin_create_db');
}

sub create_db_do {
#----------------------------------------------------------
# Create a database.

    $DB->create_db($IN->param('dbse'));
    show_dbs();
}

sub process_db {
#----------------------------------------------------------
# Show the database process list.

# Grab the database names and map them into a loop.
    my $proc_loop = [ map +{ id    => $_->[0], 
                             user  => $_->[1], 
                             host  => $_->[2], 
                             db    => $_->[3],
                             comm  => $_->[4],
                             time  => $_->[5], 
                             state => defined $_->[6] ? $_->[6] : 'NULL', 
                             info  => $_->[7] }, $DB->process_db   ];

    print $IN->header();
    $TPL->parse('admin_proc_list', { db => scalar $IN->param('db'), proc_loop => $proc_loop } );
}

sub load_db {
#----------------------------------------------------------
# Load a database.

    my $msg   = shift;
    my $ref   = $DB->load_db();
    my $db    = $IN->param('db');
    my $tmp   = [];
    my $siz   = 0;
    my ($ver) = [ $DB->show_vars ]->[-2]->[1] =~ /^(\d\.\d\d)/;

# Create a template loop.
    if (ref $ref eq 'ARRAY') {
        foreach my $table (@$ref) {
            push @$tmp, { is_323 => ($ver > 3.22 ? 1 : 0), table => $table->[0], rows => $DB->rows($table->[0]), db => $db };
            $siz += $DB->stats_table($table->[0])->[5];
        }
    }

# Find the total byte size of this database.
    
    print $IN->header();
    $TPL->parse('admin_table_list', 
         {
             size_b     => $siz, # db size in bytes
             size_kb    => sprintf("%.2f", $siz / 1000),
             size_mb    => sprintf("%.2f", $siz / 1000 / 1000),
             table_loop => $tmp, 
             db         => $db,
             tables     => scalar(@$tmp)
          } 
    );
}

sub login {
#----------------------------------------------------------
# Login a user into mysql.

    show_dbs(); 
}

sub create_table {
#----------------------------------------------------------
# Show the template for creating a new table.

    print $IN->header();
    $TPL->parse('admin_create_table', { db => scalar $IN->param('db') } );
}

sub rename_table {
#----------------------------------------------------------
# Rename table template.

    print $IN->header();
    $TPL->parse('admin_rename_table', { nav => 1, db => scalar $IN->param('db'), table => scalar $IN->param('table') } );
}

sub drop_table_warn {
#----------------------------------------------------------
# Drop table template.

    print $IN->header();
    $TPL->parse('admin_drop_table', { nav => 1, db => scalar $IN->param('db'), table => scalar $IN->param('table') } );
}

sub add_col {
#----------------------------------------------------------
# Allow new cols to be added to the table.

    my $tab = $IN->param('table');

# We need a template loop for the positions.
    my $stat = $DB->attr_table($tab);
    my $loop = [ map +{ pos => $_->[0] }, @$stat ];

    print $IN->header();
    $TPL->parse('admin_add_col', { pos_loop => $loop, nav => 1, db => scalar $IN->param('db'), table => $tab } );
}

sub add_col_attr {
#----------------------------------------------------------
# Show the template for specifying colum attributes.

    my $db  = $IN->param('db');
    my $tab = $IN->param('table');
    my $col = $IN->param('cols');
    my $pos = $IN->param('pos');
    my $tmp = [];

# Build a template loop. We don't actually have any data but it just assists with building the form.
    push(@$tmp, {}) for (1..$col);

    print $IN->header();
    $TPL->parse('admin_add_col_cols', { table => $tab, db => $db, pos => $pos, col_loop => $tmp } );
    return;
}

sub drop_table {
#----------------------------------------------------------
# Drop a table.

    $DB->drop_table($IN->param('table'));
    load_db();
}

sub drop_index {
#----------------------------------------------------------
# Drop a table index.

    $DB->drop_index($IN->param('table'), $IN->param('key'));
    attr_table();
}

sub drop_col {
#----------------------------------------------------------
# Drop a column.

    $DB->drop_col($IN->param('table'), $IN->param('col'));
    attr_table();
}

sub pri_key_add {
#----------------------------------------------------------
# Add a primary key.

    $DB->add_primary_key($IN->param('table'), $IN->param('col'));
    attr_table();
}

sub uni_key_add {
#----------------------------------------------------------
# Make the column unique.

    $DB->add_unique_key($IN->param('table'), $IN->param('col'));
    attr_table();
}

sub ind_key_add {
#----------------------------------------------------------
# Add an index.

    $DB->add_index_key($IN->param('table'), $IN->param('col'));
    attr_table();
}

sub empty_table {
#----------------------------------------------------------
# Empty a table.

    $DB->empty_table($IN->param('table'));
    load_db();
}

sub rename_table_do {
#----------------------------------------------------------
# Rename a table.

    $DB->rename_table($IN->param('table'), $IN->param('new_table'));
    load_db();
}

sub stats_table {
#----------------------------------------------------------
# Show table stats.

    my $stat = $DB->stats_table($IN->param('table'));
    my $tags = { 
                 table  => $stat->[0],
                 type   => $stat->[1],
                 format => $stat->[2], 
                 rows   => $stat->[3], 
                 arl    => $stat->[4], 
                 datlen => $stat->[5], 
                 maxdl  => $stat->[6],
                 maxdlg => sprintf("%.2f", $stat->[6] / 1073741824  ), # Supposedly the number of bytes in a gig!
                 index  => $stat->[7],
                 free   => $stat->[8],
                 ai     => $stat->[9],
                 ctime  => $stat->[10],
                 utime  => $stat->[11],
                 chtime => $stat->[12],
                 opts   => $stat->[13],
                 comm   => $stat->[14] 
    }; 

    print $IN->header();

    $TPL->parse('admin_stats_table', { nav => 1, db => scalar $IN->param('db'), %$tags } );
    return;
}

sub attr_table {
#----------------------------------------------------------
# Show columns within a table.

    my $tab      = $IN->param('table');
    my $db       = $IN->param('db');
    my $stat     = $DB->attr_table($tab);
    my $keys     = $DB->show_keys($tab, $db);
    my $col_loop = [ map +{  col     => $_->[0], 
                             type    => $_->[1],
                             null    => $_->[2], 
                             key     => $_->[3],
                             default => $_->[4], 
                             extra   => $_->[5],
                             db      => $db, 
                             table   => $tab }, @$stat ]; 

    my $key_loop = [ map +{  unique  => $_->[1],
                             null    => $_->[8], 
                             key     => $_->[2],
                             column  => $_->[4],
                             sort    => $_->[5],
                             table   => $tab,
                             db      => $db }, @$keys ];

    print $IN->header();
    $TPL->parse('admin_attr_table', 
           { 
               db       => $db, 
               table    => $tab,
               key_loop => $key_loop, 
               keys     => scalar(@$key_loop), 
               col_loop => $col_loop, 
               cols     => scalar(@$col_loop)
            } 
    );
    return;
}

sub alter_col {
#----------------------------------------------------------
# Alter a specific column.

    my $col  = $DB->get_col($IN->param('table'), $IN->param('col'));

# Just make the keys lowercase to save me grief :)
    my $lcol = map +( lc($_) => $col->{$_} ), keys %$col;

# We need to do some regexes to match the type/length/attribs.
    if (index($lcol->{type}, '(') > -1 and index($lcol->{type}, ')') > -1) {
        ($lcol->{type}, $lcol->{set}, $lcol->{attr}) = $lcol->{type} =~ /^(\w+)\(([^)]+)\)(?:\s+(?:[^\s]+\s+)?(\w+))?$/;
         $lcol->{attr} =~ s/^\s+|\s+$//g;
    }

    print $IN->header();
    $TPL->parse('admin_alter_col', { nav => 1, table => scalar $IN->param('table'), db => scalar $IN->param('db'), %$lcol } );
}

sub create_table_do {
#----------------------------------------------------------
# *Fingers crossed*

    my $input = MyAdmin::Objects->get_hash;
    my $db    = $input->{db};
    my $tab   = $input->{table_name};
    my @cols  = ();

# Loop the input matching what we want.
    foreach my $attr (keys %$input) {
        if ($attr =~ /^field_(\d+)$/) {
            next unless defined $input->{"field_$1"};
            push @cols, { 
                          field   => $input->{"field_$1"}, 
                          type    => $input->{"type_$1"}, 
                          set     => $input->{"set_$1"},
                          attr    => $input->{"attributes_$1"},
                          null    => $input->{"null_$1"},
                          default => $input->{"default_$1"},
                          extra   => $input->{"extra_$1"},
                          primary => $input->{"primary_$1"},
                          index   => $input->{"index_$1"},
                          unique  => $input->{"unique_$1"}
            };
        }
    }

# Create the table.
    $DB->create_table(\@cols, $tab);
    load_db();
}

sub add_col_do {
#----------------------------------------------------------
# *Fingers crossed* again!

    my $input = MyAdmin::Objects->get_hash;
    my $db    = $input->{db};
    my $tab   = $input->{table};
    my $pos   = $input->{pos};
    my @cols  = ();

# Loop the input matching what we want.
    foreach my $attr (keys %$input) {
        if ($attr =~ /^field_(\d+)$/) {
            next unless defined $input->{"field_$1"};
            push @cols, { 
                          field   => $input->{"field_$1"}, 
                          type    => $input->{"type_$1"}, 
                          set     => $input->{"set_$1"},
                          attr    => $input->{"attributes_$1"},
                          null    => $input->{"null_$1"},
                          default => $input->{"default_$1"},
                          extra   => $input->{"extra_$1"},
                          primary => $input->{"primary_$1"},
                          index   => $input->{"index_$1"},
                          unique  => $input->{"unique_$1"}
            };
        }
    }

# Create the table.
    $DB->add_cols(\@cols, $tab, $pos);
    attr_table();
}

sub alter_col_do {
#----------------------------------------------------------
# *Fingers crossed* thrice!

    my $input = MyAdmin::Objects->get_hash;
    my $db    = $input->{db};
    my $tab   = $input->{table};
    my $name  = $input->{col};

# Match what we want.
    my $col = { field   => $input->{"field"}, 
                type    => $input->{"type"}, 
                set     => $input->{"set"},
                attr    => $input->{"attributes"},
                null    => $input->{"null"},
                default => $input->{"default"},
                extra   => $input->{"extra"}
    };

# Alter the column.
    $DB->alter_col($col, $tab, $name);
    attr_table();
}

sub create_table_cols {
#----------------------------------------------------------
# Show the template for specifying colum attributes.

    my $db  = $IN->param('db');
    my $tab = $IN->param('table_name');
    my $col = $IN->param('table_cols');
    my $tmp = [];

# Build a template loop. We don't actually have any data but it just assists with building the form.
    push(@$tmp, {}) for (1..$col);

    print $IN->header();
    $TPL->parse('admin_create_table_cols', { table_name => $tab, db => $db, col_loop => $tmp } );
    return;
}

sub dump_db_do {
#----------------------------------------------------------
# Let's dump the database.

    my $db   = $IN->param('db');
    my $loc  = $IN->param('location');
    my $path = $IN->param('path');
    my $cre  = $IN->param('create');
    my $ins  = $IN->param('insert');
    my $drop = $IN->param('drop');
    my $del  = $IN->param('delayed');
    my $com  = $IN->param('complete');
    my $mul  = $IN->param('multi');
    my $ref  = $DB->load_db;
    my @tabs = ();
    my $out  = '';
  
# Load the tables.
    @tabs = $IN->param('tables') == 1 ? map { $_->[0] } @$ref : $IN->param('table');

# Start building output.
    foreach my $table (@tabs) {
        $out .= $DB->dump_table($db, $table, $cre, $ins, $drop, $del, $com, $mul);
    }

    if ($loc) {
        print $IN->header('text/plain');
        print "#" . ("=" x 75) . "\n# PerlMyAdmin Database Dump.\n# Generated on " . scalar(localtime) . "\n";
        print "# Support: http://www.supportsql.com/cgi-bin/forum/gforum.cgi\n";
        print "# Database: $db\n" . "#" . ("=" x 75) . "\n\n";
        print $out;
        print "\n# End of dump\n";
        exit 0;
    }

# We are printing to a file.
    else {
        if ($path =~ /\.\w+$/) {
            if (open DUMP, ">", $path) {
                print DUMP "#" . ("=" x 75) . "\n# PerlMyAdmin Database Dump.\n# Generated on " . scalar(localtime) . "\n";
                print DUMP "# Support: http://www.supportsql.com/cgi-bin/forum/gforum.cgi\n";
                print DUMP "# Database: $db\n" . "#" . ("=" x 75) . "\n\n";
                print DUMP $out;
                print DUMP "\n# End of dump\n";
                close DUMP;
            }
            else {
                print $IN->header();
                $TPL->parse('admin_error', { error => sprintf($ERRORS->{CANTDUMP}, $path, $!) } );
                return;
            }
        }
        else {
            print $IN->header();
            $TPL->parse('admin_error', { error => $ERRORS->{DUMPFILE} } );
            return;
        }
        my $s = -s $path;
        my $k = sprintf("%.2f", $s / 1000);
        my $m = sprintf("%.2f", $k / 1000);
        print $IN->header();
        $TPL->parse('admin_dump_done', { db => $db, path => $path, size => $s, kb => $k, mb => $m } );
        return;
    }
}

sub delete_row {
#----------------------------------------------------------
# Delete a row from a table.
  
    my $table = $IN->param('table');
    my $where = $IN->param('del');

    $DB->delete_row($table, $where);

    browse_table();    
}

sub edit_row_do {
#----------------------------------------------------------
# Actually edit the row.

    my $input = MyAdmin::Objects->get_hash;
    my $where = $input->{where};
    my $table = $input->{table};
    my @cols  = map { $input->{$_}->[0] } grep ref $input->{$_} eq 'ARRAY', keys %$input;
    my $updat = "UPDATE $table SET ";

# Loop the output and build the query.
    foreach my $key (keys %$input) {
        next unless ref $input->{$key} eq 'ARRAY'; # Should have 4 fields, empty or not.
        $updat .= $input->{$key}->[0] . ' = ';
        if ($input->{$key}->[3] == 1) {
            $updat .= "NULL, ";
            next;
        }
        elsif ($input->{$key}->[1]) {
            $updat .= $input->{$key}->[1] . "(" . $DB->{dbh}->quote($input->{$key}->[2]) . "), ";
            next;
        }

# We use a little bit of sexiness here to join multiple values but it will still work with single values.
        else {
            $updat .= $DB->{dbh}->quote( join(',', @{$input->{$key}}[2..$#{$input->{$key}}]) ) . ", ";
            next;
        }
    }
    $updat =~ s/[, ]+$//; # Stip commas/spaces.
    $updat .= " WHERE $where LIMIT 1";

# Execute the query.
    $DB->edit_row($updat);

    browse_table();
} 

sub edit_row {
#----------------------------------------------------------
# Load the edit page to be able to edit a row.
  
    my $input = MyAdmin::Objects->get_hash;
    my $where = $input->{edit};
    my $query = "SELECT * FROM $input->{table} WHERE $where";
    my $sth   = $DB->prepare_sth($query);
    my $attr  = $DB->attr_table($input->{table});
    my $loop  = [];

# We use a loop to be able to match col names and values, otherwise it gets tricky.
    while (my @rec = $sth->fetchrow) {
        for (my $i = 0; $i < @rec; $i++) {
            my ($field);
            my ($full, $type, $set) = $attr->[$i]->[1] =~ /^((\w+)(?:\(([^)]+)\))?)/;
            if ($type eq 'enum' or $type eq 'set') {
                my @parts = grep $_, split /[',]+/, $set;
                my @vals  = split /,/, $rec[$i];
                foreach my $part (@parts) {
                    $field .= qq|<input type="checkbox" name="$sth->{NAME}->[$i]" value="$part" |;
                    $field .= qq|checked| if grep /^\Q$part\E$/, @vals;
                    $field .= qq|> $part<br>|;
                }
            }
            elsif (substr($type, -4, 4) eq 'text' or substr($type, -4, 4) eq 'blob') {
                $field .= qq|<textarea name="$sth->{NAME}->[$i]" rows="5" cols="25">$rec[$i]</textarea>|;
            }
            else {
                $field = qq|<input type="text" class="text" name="$sth->{NAME}->[$i]" size="30" value="$rec[$i]">|;
            }
            push @$loop, { isnull   => defined $rec[$i] ? 0 : 1,
                           null     => $attr->[$i]->[2], 
                           type     => $full, 
                           field    => $field, 
                           col_name => $sth->{NAME}->[$i] };
        }
    }

    print $IN->header();
    $TPL->parse('admin_edit_row', { %$input, where => $where, row_loop => $loop } );
}

sub insert_table {
#----------------------------------------------------------
# Load the table allowing a user to insert a new row.
  
    my $table = $IN->param('table');
    my $db    = $IN->param('db');
    my $attr  = $DB->attr_table($table);
    my $loop  = [];
    my $field;

# Generate a template loop.
    foreach my $att (@$attr) {
        my ($full, $type, $set) = $att->[1] =~ /^((\w+)(?:\(([^)]+)\))?)/;
        if ($type eq 'enum' or $type eq 'set') {
            my @parts = grep $_, split /[',]+/, $set;
            $field = qq|<select name="$att->[0]">|;
            foreach my $part (@parts) {
                $field .= qq|<option |;
                $field .= qq|selected| if lc($att->[4] eq $part);
                $field .= qq|>$part</option>|;
            }
            $field .= qq|</select>|;
        }
        elsif (substr($type, -4, 4) eq 'text' or substr($type, -4, 4) eq 'blob') {
            $field = qq|<textarea name="$att->[0]" rows="5" cols="25"></textarea>|;
        }
        else {
            $field = qq|<input type="text" name="$att->[0]" size="35" class="text">|;
        }
        push @$loop, { col => $att->[0], type => $att->[1], null => $att->[2], field => $field };
    }

    print $IN->header();
    $TPL->parse('admin_insert_table', { table => $table, db => $db, col_loop => $loop } );
}

sub insert_table_do {
#----------------------------------------------------------
# Insert the new row.
  
    my $input = MyAdmin::Objects->get_hash;
    my $table = $IN->param('table');
    my @cols  = grep ref $input->{$_} eq 'ARRAY', keys %$input;
    my $query = "INSERT INTO $table (" . join (',', @cols) . ") VALUES (";

# Loop the input.
    foreach my $key (keys %$input) {
        next unless ref $input->{$key} eq 'ARRAY';
        if ($input->{$key}->[2] == 1) {
            $query .= "NULL,";
            next;
        }
        elsif ($input->{$key}->[0]) {
            $query .= $input->{$key}->[0] . "(" . $DB->{dbh}->quote($input->{$key}->[1]) . "),";
        }
        else {
            $query .= $DB->{dbh}->quote($input->{$key}->[1]) . ",";
        }
    }
    $query =~ s/[, ]+$//;
    $query .= ")";

    $DB->insert_row($query);

    load_db();
}

sub browse_table {
#----------------------------------------------------------
# Browse a table. Quite complexed, sigh!

    my ($table, $db, $page) = ($IN->param('table'), $IN->param('db'), ($IN->param('page') || 1));
    my ($sf, $so)           = ($IN->param('sf'), $IN->param('so'));
    my ($low, $j)           = (0, 0);
    my $high                = $CFG->{rows_per_page} || 15;
    my $attr                = $DB->attr_table($table);
    my @pri                 = map { $_->[0] } grep $_->[3] eq 'PRI', @$attr;
    my @cols                = map { $_->[0] } @$attr; 
    my @mod                 = ();
    my ($out, $clss, $sort, $sth, $quer, $total, $keys, $qc);

    ($page > 1) and $low = ($page - 1) * $high;

# Select the keys.
    $keys = ( "," . join(",", @pri) ) if @pri;

# The queries.
    $so  ||= 'ASC';
    $sf    = $sf || $pri[0] || '';
    $sort  = ($sf and $so) ? "ORDER BY $sf $so" : '';
    $quer  = "SELECT *$keys FROM $table $sort LIMIT $low, $high";
    $qc    = "SELECT * FROM $table $sort LIMIT $low, $high";
    $sth   = $DB->prepare_sth($quer);
    $total = $DB->rows($table);

    while (my @rec = $sth->fetchrow) {
        $j++;
        $clss = $j % 2 ? 'td_even' : 'td_odd';
        $out .= "<tr>";

# Build up the output. Start by doing some formatting.
        for (my $i = 0; $i < @rec; $i++) {
             if ($i < @rec - @pri) {
                 $rec[$i] =~ s/[\r\n]+/<BR>/g;
                 $rec[$i] =~ s/\t+/"&nbsp;" x 3/eg;
                 $rec[$i] =~ s/\s+/&nbsp;/g;
                 if (defined $rec[$i]) {
                     $out .= $rec[$i] ne '' ? "<td class='$clss'>$rec[$i]</td>" : "<td class='$clss'>&nbsp;</font></td>";
                 }

# It is a null value.
                 else {
                     $out .= qq|<td class="$clss"><font color="#C00000"><b>NULL</b></font></td>|;
                 }
             }

# This must be a key, we need this for editing/deleting rows.
             else{
                 my $val = $DB->{dbh}->quote($rec[$i]);
                 my $col = $sth->{NAME}->[$i];
                 push @mod, "$col = $val";
             }
        }
        if ($keys) {
            my $to_mod = $IN->escape( join(' AND ', @mod) );
            $out .= "<td class='$clss'><a href='myadmin.cgi?do=edit_row&db=$db&table=$table&page=$page&sf=$sf&so=$so&edit=$to_mod'>Edit</a></td>";
            $out .= "<td class='$clss'><a href='myadmin.cgi?do=delete_row&db=$db&table=$table&sf=$sf&so=$so&page=$page&del=$to_mod'";
            $out .= " onclick='return do_confirm();" if $CFG->{confirm_delete};
            $out .= "'>Delete</a></td>";
        }
        $out .= "</tr>";
        @mod = ();
    }

# Add the column names to the output.
    $out = "<tr><td class='td_color_header'>" . join("</td><td class='td_color_header'>", map { "<a href='myadmin.cgi?do=browse_table&db=$db&table=$table&page=$page&sf=$_&so=$so'><b>$_</b></a>" } @cols) . "</td></tr>" . $out;

# Build a toolbar.
    my $toolbar = WO::Base::toolbar( { per_page => $high, 
                                       spread   => 17, 
	                                   page     => $page, 
	                                   url      => "myadmin.cgi?do=browse_table&db=$db&table=$table&sf=$sf&so=$so", 
	                                   show_max => 7, 
	                                   total    => $total } ) if $total;

    print $IN->header();
    $TPL->parse('admin_browse_table', 
           { 
              toolbar => $toolbar,
              hits    => $total, 
              query   => $qc, 
              output  => $out, 
              db      => scalar $IN->param('db'), 
              table   => $table 
           } 
    );

}

sub query_db {
#----------------------------------------------------------
# Show the page allowing queries to be entered.

    print $IN->header();
    $TPL->parse('admin_query_db', { db => scalar $IN->param('db') } );
}

sub query_db_do {
#----------------------------------------------------------
# Query the database.
# I know I know, it's getting repetitive but it seems clearer this way (I think!)
# There are also a few changes between these look-a-like routines so it's better this way.

    my ($sth, $out, $clss, $query);
    my ($j)     = -1;
    my ($low)   = 0;
    my ($total) = 0;
    my ($page)  = $IN->param('page') || 1;
    my ($pp)    = 20;
    my ($db)    = $IN->param('db');
    my (@cols)  = ();

    ($page > 1) and $low = ($page -1) * $pp;
    
# An inputted query.
    if ($IN->param('query')) {
        $query = $IN->param('query');
    }

# A local file.
    elsif ($IN->param('lpath')) {
        my $buff = $IN->param('lpath');
        $query .= $_ while (<$buff>);
    }

# A server file.
    elsif ($IN->param('spath')) {
        my $buff = $IN->param('spath');

# Error check.
        if ($buff !~ /\.\w+$/) {
            print $IN->header();
            $TPL->parse('admin_error', { error => sprintf($ERRORS->{SERVERFILE}, $buff) } );
            return;
        }
        if (open  BUF, $buff) {
            read  BUF, $query, -s BUF;
            close BUF;
        }
        else {
            print $IN->header();
            $TPL->parse('admin_error', { error => sprintf($ERRORS->{SERVERQ}, $buff, $!) } );
            return;
        }
    }

# Try to clean things a bit.
    $query =~ s/\r?\n/ /g;

    $sth   = $DB->prepare_sth($query);
    $total = $sth->rows;

# Begin looping output.
    while (my @rec = $sth->fetchrow) {
        $j++;
        if ($j >= $low and $j < ($pp + $low)) { 
            $clss = $j % 2 ? 'td_even' : 'td_odd';
            $out .= "<tr>";

# Build up the output. Start by doing some formatting.
            for (my $i = 0; $i < @rec; $i++) {
                 if ($i < @rec) {
                     $rec[$i] =~ s/[\r\n]+/<BR>/g;
                     $rec[$i] =~ s/\t+/"&nbsp;" x 3/eg;
                     $rec[$i] =~ s/\s+/&nbsp;/g;
                     if (defined $rec[$i]) {
                         $out .= $rec[$i] ne '' ? "<td class='$clss'>$rec[$i]</td>" : "<td class='$clss'>&nbsp;</font></td>";
                     }   
                     else {
                         $out .= qq|<td class="$clss"><font color="#C00000"><b>NULL</b></font></td>|;
                     }
                 }
                 push (@cols, $sth->{NAME}->[$i]) unless @rec == @cols;
            }
        }

# This should hopefully increase speed as it stops the loop as soon as we have what we need.
        elsif ($j > ($pp + $low)) { last }
    }
    $sth->finish();

# Add the column names to the output.
    $out = "<tr><td class='td_color_header'>" . join("</td><td class='td_color_header'>", map "<b>$_</b>", @cols) . "</td></tr>" . $out;
    $out .= "</tr>";

# Build a toolbar.
    my $toolbar = WO::Base::toolbar( { per_page => $pp, 
                                       spread   => 17, 
	                                   page     => $page, 
	                                   url      => ("myadmin.cgi?do=query_db_do&db=$db&query=" . $IN->escape($query)), 
	                                   show_max => 7, 
	                                   total    => $total } ) if $total;

    print $IN->header();
    $TPL->parse('admin_query_table', 
           { 
              toolbar => $toolbar, hits => $total, query => $query, output => $out, db => $db
           } 
    );
}

sub search_table {
#----------------------------------------------------------
# Display the search page.

    my $table    = $IN->param('table');
    my $attr     = $DB->attr_table($table);
    my $col_loop = [];

# Build a template loop.
    foreach my $att (@$attr) {
        my ($type) = $att->[1] =~ /^(\w+)/;
        push @$col_loop, { col => $att->[0], type => $type };
    }

    print $IN->header();
    $TPL->parse('admin_search_table', { eg => $attr->[0]->[0], db => scalar $IN->param('db'), table => $table, col_loop => $col_loop } );
}

sub search_table_do {
#----------------------------------------------------------
# Perform a search.

    my ($sth, $out, $clss, $query, $keys);
    my ($j)     = -1;
    my ($low)   = 0;
    my ($total) = 0;
    my ($page)  = $IN->param('page') || 1;
    my ($pp)    = 20;
    my ($db)    = $IN->param('db');
    my ($table) = $IN->param('table');
    my ($where) = $IN->param('where');
    my ($attr)  = $DB->attr_table($table);
    my (@cls)   = $IN->param('c') ? split(',', $IN->param('c')) : $IN->param('col');
    my ($q)     = $IN->param('query');
    my (@pri)   = map { $_->[0] } grep $_->[3] eq 'PRI', @$attr;
    my (@mod)   = ();

    ($page > 1) and $low = ($page -1) * $pp;

# Join the keys.
     $keys = ( "," . join(",", @pri) ) if @pri;

# Build the query.
     if (! $q) {
         $query .= "SELECT ";
         $query .= @cls ? ( join(',', @cls) . "$keys" ) : "*$keys";
         $query .= " FROM $table";
         $query .= " WHERE $where" if $where;
     }
     else {
         $query = $q;
     }

# Try to clean things a bit.
    $query =~ s/\r?\n/ /g;

    $sth   = $DB->prepare_sth($query);
    $total = $sth->rows;

# If using a wildcard, grab all col names.
    @cls = map { $_->[0] } @$attr unless @cls;

# Begin looping output.
    while (my @rec = $sth->fetchrow) {
        $j++;
        if ($j >= $low and $j < ($pp + $low)) { 
            $clss = $j % 2 ? 'td_even' : 'td_odd';
            $out .= "<tr>";

# Build up the output. Start by doing some formatting.
            for (my $i = 0; $i < @rec; $i++) {
                 if ($i < @rec - @pri) {
                     $rec[$i] =~ s/[\r\n]+/<BR>/g;
                     $rec[$i] =~ s/\t+/"&nbsp;" x 3/eg;
                     $rec[$i] =~ s/\s+/&nbsp;/g;
                     if (defined $rec[$i]) {
                         $out .= $rec[$i] ne '' ? "<td class='$clss'>$rec[$i]</td>" : "<td class='$clss'>&nbsp;</font></td>";
                     }   
                     else {
                         $out .= qq|<td class="$clss"><font color="#C00000"><b>NULL</b></font></td>|;
                     }
                 }
# This must be a key, we need this for editing/deleting rows.
                 else{
                     my $val = $DB->{dbh}->quote($rec[$i]);
                     my $col = $sth->{NAME}->[$i];
                     push @mod, "$col = $val";
                }
            }
            if ($keys) {
                my $to_mod = $IN->escape( join(' AND ', @mod) );
                $out .= "<td class='$clss'><a href='myadmin.cgi?do=edit_row&db=$db&table=$table&page=$page&edit=$to_mod'>Edit</a></td>";
                $out .= "<td class='$clss'><a href='myadmin.cgi?do=delete_row&db=$db&table=$table&page=$page&del=$to_mod'";
                $out .= " onclick='return do_confirm();" if $CFG->{confirm_delete};
                $out .= "'>Delete</a></td>";
            }
            $out .= "</tr>";
            @mod = ();
        }
        
# This should hopefully increase speed as it stops the loop as soon as we have what we need.
        elsif ($j > ($pp + $low)) { last }
    }

# Add the column names to the output.
    $out = "<tr><td class='td_color_header'>" . join("</td><td class='td_color_header'>", map "<b>$_</b>", @cls) . "</td></tr>" . $out;
    $out .= "</tr>";

# Build a toolbar.
    my $c       = join(',',@cls);
    my $toolbar = WO::Base::toolbar( { per_page => $pp, 
                                       spread   => 17, 
	                                   page     => $page, 
	                                   url      => ("myadmin.cgi?do=search_table_do&db=$db&table=$table&c=$c&query=" . $IN->escape($query)), 
	                                   show_max => 7, 
	                                   total    => $total } ) if $total;

    print $IN->header();
    $TPL->parse('admin_search_results', 
           { 
              toolbar => $toolbar, hits => $total, query => $query, output => $out, db => $db, table => $table
           } 
    );
}

sub logout {
#----------------------------------------------------------
# Log the user out.

    my $a = $IN->cookie( -name => $CFG->{ck_pass}, -value => '', -path => '/', -expires => '-1y' );

    print $IN->header( -cookie => [$a] );
    $TPL->parse('admin_login', { error => $ERRORS->{LOGOUT} } );
}

sub export_table {
#----------------------------------------------------------
# Show the table export page.

    require Cwd;
    my $cwd   = Cwd::cwd();
    my $table = scalar $IN->param('table');
    my $dat   = join('-', (split /\s/, scalar localtime)[1,2,4]);
    my $loop  = [ map +{ field => $_->[0] }, @{$DB->attr_table($table)} ];

    print $IN->header();
    $TPL->parse('admin_export_table', 
            { 
               loop  => $loop,
               date  => $dat, 
               cwd   => $cwd, 
               db    => scalar $IN->param('db'), 
               table => $table 
            } 
    );
}

sub export_table_do {
#----------------------------------------------------------
# Do the export.

    my $db    = $IN->param('db');
    my $table = $IN->param('table');
    my $loc   = $IN->param('location');
    my @fld   = $IN->param('field');
    my $flds  = $IN->param('fields');
    my $esc   = $IN->param('esc');
    my $path  = $loc == 1 ? temp_file() : $IN->param('path');
    my $fsep  = $IN->param('fsep');
    my $rsep  = $IN->param('rsep');
    my $join  = $flds == 1 ? '*' : join(',', @fld);

# Check the file name.
    if ($path !~ /\.?\w+$/) {
        print $IN->header();
        $TPL->parse('admin_error', { error => $ERRORS->{EXPFILE} } );
        return;
    }
    
# Export the data.
    $DB->export_data($path, $table, $join, $rsep, $fsep, $esc); # Path, cols, rec sep, field sep, escape char

# Are we printing to screen?
    if ($loc == 1) {
        if (open TMP, $path) {
            print $IN->header('text/plain');
            print "#" . ("=" x 75) . "\n# PerlMyAdmin Table Export.\n# Generated on " . scalar(localtime) . "\n";
            print "# Support: http://www.supportsql.com/cgi-bin/forum/gforum.cgi\n";
            print "# Database: $db\n";
            print "# Table: $table\n" . "#" . ("=" x 75) . "\n\n";
            print while (<TMP>);
            print "\n# End of export\n";
            close TMP;
            unlink $path;
        }
        else {
            print $IN->header();
            $TPL->parse('admin_error', { error => sprintf($ERRORS->{EXPORTF}, $path, $!) } );
            return;
        }
        return;
    }

    print $IN->header();
    $TPL->parse('admin_export_done', { db => $db, table => $table, file => $path, size => sprintf("%.2f", ((-s $path) / 1000)) } );
    return;
}

sub import_table {
#----------------------------------------------------------
# Show the table import page.

    require Cwd;
    my $table  = $IN->param('table');
    my $db     = $IN->param('db');
    my $dir    = Cwd::cwd() . '/exports';
    my $c_loop = [ map +{ field => $_->[0] }, @{$DB->attr_table($table)} ];
    my $loop   = [];

# Read the exports dir for existing files reading to import.
    if (opendir DIR, $dir) {
        push @$loop, map +{ exp => $_ }, grep { !/^\./ } readdir(DIR);
        closedir DIR;
    }
    else {
        print $IN->header();
        $TPL->parse('admin_error', { error => sprintf($ERRORS->{EXPDIR}, $dir, $!) } );
        return;
    }

    print $IN->header();
    $TPL->parse('admin_import_table', 
            { 
               c_loop => $c_loop,
               loop   => $loop,
               exps   => scalar @$loop,
               db     => scalar $IN->param('db'), 
               table  => $table 
            } 
    );
}

sub import_table_do {
#----------------------------------------------------------
# Perform the import.

    require Cwd;
    my $me    = Cwd::cwd();
    my $fld   = $IN->param('fields');
    my @fld   = $IN->param('field');
    my $not   = $IN->param('location1');
    my $exist = $IN->param('location2');
    my $table = $IN->param('table');
    my $db    = $IN->param('db');
    my $rsep  = $IN->param('rsep');
    my $fsep  = $IN->param('fsep');
    my $esc   = $IN->param('esc');
    my $skp   = $IN->param('skip');
    my $ow    = $IN->param('ow') || 'IGNORE';
    my $path  =  $exist ? ($me . '/exports/' . $exist) : $not;
    my $join  = $fld == 1 ? '*' : join(',', @fld);

# Quick error check.
    if ($path !~ /\.?\w+$/) {
        print $IN->header();
        $TPL->parse('admin_error', { error => $ERRORS->{IMPFILE} } );
        return;
    }

# If we are showing errors then don't replace or ignore.
    $ow = '' if ($IN->param('er'));

    $DB->import_data($path, $table, $join, $rsep, $fsep, $esc, $skp, $ow);

    browse_table();
}

sub man_users {
#----------------------------------------------------------
# A nice little user management feature.

    my $msg = $IN->param('grants');
    my $db  = $IN->param('db');

# Make sure someone isn't trying to cheat ;)
    unless ($db eq 'mysql') {
        print $IN->header();
        $TPL->parse('admin_error', { error => $ERRORS->{WRONGDB} } );
        return;
    }

    my $user_loop = [ map +{ db => $db, host => $_->[0], user => $_->[1] }, @{$DB->load_users('Host','User')} ];

    print $IN->header();
    $TPL->parse('admin_man_users', { grants => $msg, host => scalar $IN->cookie($CFG->{ck_host}), user_loop => $user_loop } );
}

sub grants_users {
#----------------------------------------------------------
# Show grants for a user.

    my $user = $IN->param('user');
    my $host = $IN->cookie($CFG->{ck_host}) || 'localhost';

    $IN->param('grants', $DB->show_grants($user, $host));

    man_users();
}

sub _set_cookies {
#----------------------------------------------------------
# Set the cookies for the script to use.

    my $e = $IN->param('save') ? '+1y' : '';
    my $p = _crypt($IN->param('pass')); # Vaguely more secure that doing nothing.
    my $a = $IN->cookie( -name => $CFG->{ck_host}, -value => $IN->param('host'), -path => '/', -expires => $e );
    my $b = $IN->cookie( -name => $CFG->{ck_user}, -value => $IN->param('user'), -path => '/', -expires => $e );
    my $c = $IN->cookie( -name => $CFG->{ck_pass}, -value => $p,                 -path => '/', -expires => $e );

    return [$a, $b, $c];
}

sub _crypt {
#----------------------------------------------------------
# Gently encrypt.

    return ( reverse ( join("\0", map { ord } split //, shift) ) );
}

sub _decrypt {
#----------------------------------------------------------
# Decrypt a gently encrypted string.

    return ( scalar reverse ( join('', map { chr scalar reverse } split "\0" => shift) ) );
}

sub sql_error {
#----------------------------------------------------------
# SQL error handler.

    shift; # Remove class.
    print $IN->header();
    $TPL->parse('admin_sql_error', { error => shift } );
    exit 1;
}

sub fatal {
#----------------------------------------------------------
# Error handler.

    print qq|Content-type: text/html\n\n|;
    print qq|<font face="tahoma" size="2">MyAdmin encountered an error whilst handling this action:<br><br>|;
    print qq|$_[0]|;
    print qq|</font>|;
    exit 1;
}

sub temp_file{
# ---------------------------------------------------
# This function creates a random temp file.

    my $rand = '';
    my $temp = '';    
    my $dir  = '.'; # Use current directory if we can't find anything better.
    my @dirs = qw|/usr/tmp /var/tmp C:/temp /tmp /temp /WWW_ROOT|;

# Does the directory exist and is it writable?
    ($dir) = grep -d $_ && -w _, @dirs; # We need ( ) otherwise $dir will be 1 or 0
    
# Keep generating random file names if the current one is taken.
    $rand = "PMA" . time . $$ . int(rand(1000));
    $rand = "PMA" . time . $$ . int(rand(1000)) while (-e $dir . '/' . $rand);

    return ( $dir . '/' . $rand );
}


1;
