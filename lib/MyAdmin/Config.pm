#==========================================================
# SupportSQL Module - http://supportsql.com/
# Project: PerlMyAdmin
# Module:  MyAdmin::Config
# Author:  Paul Wilson
# $Id:     Config.pm,v 1.00 2002/08/20 00:57:51 paul Exp $
#
# Copyright (c) 2002, SupportSQL.  All Rights Reserved.
#==========================================================
# Description:
# Configuration file.
#==========================================================

  package MyAdmin::Config;
#==========================================================

  use strict;
  use vars qw/$CFG @ISA @EXPORT @EXPORT_OK/;
  @EXPORT_OK = ();
  @EXPORT    = qw/$CFG/;
  @ISA       = qw/Exporter/;

#==========================================================

  $CFG = {
            path    => '.',
            db      => '',
            host    => 'localhost',
            user    => '',
            pass    => '',
            auto    => 0,
            debug   => 0,
            ck_host => 'MYADM_HOST',
            ck_dbse => 'MYADM_DB',
            ck_user => 'MYADM_USER',
            ck_pass => 'MYADM_PASS',
            rows_per_page  => 15,
            confirm_delete => 1,
            actions => [qw/login 
                           show_vars 
                           show_dbs 
                           logout 
                           show_status 
                           drop_db 
                           create_db
                           create_db_do
                           load_db 
                           process_db 
                           create_table 
                           create_table_cols
                           create_table_do
                           drop_table
                           empty_table
                           stats_table
                           attr_table
                           drop_index
                           drop_col
                           alter_col
                           alter_col_do
                           rename_table
                           rename_table_do
                           pri_key_add
                           ind_key_add
                           uni_key_add
                           add_col
                           add_col_attr
                           add_col_do
                           drop_table_warn
                           insert_table
                           dump_db
                           dump_db_do
                           browse_table
                           delete_row
                           edit_row
                           edit_row_do
                           insert_table_do
                           query_db
                           query_db_do
                           search_table
                           search_table_do
                           export_table
                           export_table_do
                           import_table
                           import_table_do
                           man_users
                           grants_users/]
  };

1;