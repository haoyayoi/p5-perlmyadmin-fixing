#==========================================================
# SupportSQL Module - http://supportsql.com/
# Project: PerlMyAdmin
# Module:  WO::Base.pm
# Author:  Paul Wilson
# $Id:     Base.pm,v 1.00 2002/08/20 01:50:42 paul Exp $
#
# Copyright (c) 2002, SupportSQL.  All Rights Reserved.
#==========================================================
# Description:
# Base class. All other classes inherit the error method.
#==========================================================

  package WO::Base;
#==========================================================

  use strict;
  
#==========================================================

sub error {
#----------------------------------------------------------
# Global error routine, inherited by all classes.

    my $self = shift;
    my $err  = shift;
    my @args = ref $_[0] ? @{$_[0]} : $_[0];
    my $hdr  = $_[1];
    my ($pkg, $file, $line) = caller;
    
# Parse the error message with the other arguments if they exist.
    my $msg = scalar(@args) ? sprintf($err, @args) : $err;
    
    print qq|Content-type: text/html\n\n| unless $hdr;
    print qq|<font face="tahoma" size="2">MyAdmin encountered an error whilst handling this action:<br><br>|;
    print qq|$msg<br><br>|;
    print qq|Caller: $pkg, $file, $line</font>|;
    exit 1;
}

sub toolbar {
#----------------------------------------------------------
# Create a groovy toolbar.

    my $url      = $_[0]->{url};
    my $per_page = $_[0]->{per_page};
    my $tot      = $_[0]->{total};
    my $page     = $_[0]->{page};
    my $spread   = $_[0]->{spread};
    my $smax     = $_[0]->{show_max};
    my $next     = $page + 1;
    my $last     = $page - 1;
    my $span     = int ($tot / $per_page); 
    my $output   = $page > 1 ? qq|<a href="$url&page=1&spread=$spread">[<<]</a> <a href="$url&page=$last&spread=$spread">[<]</a> | : "[<<] [<]";
    my $low      = 1;
    my $high;

# No point carrying on.
	return unless $tot > $per_page;

    $output .= qq| <a href="$url&page=1&spread=$spread">1</a> ... | if ($smax and ($page > (1 + int($spread / 2))));

# Stops the span being too short.
    ($span * $per_page < $tot) and $span++;

# If the spread is set above the actual span then we need to allow for that.
    if ($span < $spread) {
	  $spread = $span; # $span % 2 ? $span - 1 : $span;
	  $low    = 1;
	  $high   = $span; # 1 + ($spread - 1);
    }

# Otherwise calculate things normally.
    else {
	  $low  = ($page - (($spread - 1) / 2));
	  $high = ($low  + ($spread - 1)) > $span ? $span : ($low + ($spread - 1));
    }

# If the low point plus the spread goes over the span then center the spanning.
    (($low + $spread) > $span) and $low = $span - ($spread - 1);

# Make sure we don't get minus numbers.
    if (($page - (($spread - 1) / 2)) < 1) {
	  $low = 1;
	  $high = $low + ($spread - 1);
    }

# If we have a bogus page, do something error like...ugh Drew forced me into it :(
    $page > $span and $page = $span;

# Build the output.
    $output .= ($page == $_) ? " <b>$_</b> " : qq|<a href="$url&page=$_&spread=$spread"><b>$_</b></a> | for ($low..$high);
    $output .= qq| ... <a href="$url&page=$span&spread=$spread">$span</a>| if ($smax and ($page < ($span - int($spread / 2))));
    $output .= ($next <= $span) ? qq| <a href="$url&page=$next&spread=$spread">[>]</a> <a href="$url&page=$span&spread=$spread">[>>]</a> | : "[>] [>>]";
	
    return $output;

}

1;