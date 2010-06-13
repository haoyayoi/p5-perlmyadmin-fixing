#==========================================================
# SupportSQL Module - http://supportsql.com/
# Project: PerlMyAdmin
# Module:  MyAdmin::Objects
# Author:  Paul Wilson
# $Id:     Objects.pm,v 1.00 2002/08/20 01:08:21 paul Exp $
#
# Copyright (c) 2002, SupportSQL.  All Rights Reserved.
#==========================================================
# Description:
# Create and export objects.
#==========================================================

  package MyAdmin::Objects;
#==========================================================

  use CGI;
  use strict;
  use warnings;
  use WO::MySQL;
  use WO::Template;
  use vars qw/$IN $DB $TPL/;

#==========================================================

sub init {
#----------------------------------------------------------
# Create the new objects.

    $IN  = new CGI;
    $DB  = new WO::MySQL;
    $TPL = new WO::Template;
}

sub import {
#----------------------------------------------------------
# Create objects and export on demand.

    my $pkg     = shift;
    my $caller  = caller;
    my @objects = $ENV{MOD_PERL} ? qw($IN $DB $TPL) : @_;

# Let's see which objects were requested.
    foreach my $o (@objects) {
        no strict 'refs'; # We are using symbol refs.
        CASE: {
            ($o eq '$IN')       and *{$caller . '::IN'}    = \$IN,   next;
            ($o eq '$DB')       and *{$caller . '::DB'}    = \$DB,   next;
            ($o eq '$TPL')      and *{$caller . '::TPL'}   = \$TPL,  next;
            die "Invalid object: $o imported by $caller";
        }
    }
}

sub get_hash {
#----------------------------------------------------------
# Returns a hashref of name/value pairs.

    my $params = ();
    my $input  = {};

# Loop through the input.
    for ($IN->param()) {
	   @$params = $IN->param($_);
	   @$params > 1 ? (@{$input->{$_}} = @$params) : ($input->{$_} = $IN->param($_));
    }

    return $input;
}
    
1;
