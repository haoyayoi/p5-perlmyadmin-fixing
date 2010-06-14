#!/usr/bin/perl
#==========================================================
# SupportSQL Script - http://supportsql.com/
# Project: PerlMyAdmin
# Script:  myadmin.cgi
# Author:  Paul Wilson
# $Id:     myadmin.cgi,v 1.00 2002/08/20 00:44:56 paul Exp $
#
# Copyright (c) 2002, SupportSQL.  All Rights Reserved.
#==========================================================
# Description:
# MySQL Management Script.
#==========================================================

  use strict;
  use warnings;
  use Cwd;
  my $cwd = getcwd();
  BEGIN{ unshift @INC, '/Users/haoyayoi/perl5/lib/perl5'; }
  use lib qw($cwd . '/lib');
  use FindBin::libs;
  use MyAdmin::Objects;
  use MyAdmin::Functions;

  local $SIG{__DIE__} = \&MyAdmin::Functions::fatal;

#==========================================================

# Here we are initializing new objects.
  MyAdmin::Objects::init();

# Now we can continue.
  MyAdmin::Functions::handle();
