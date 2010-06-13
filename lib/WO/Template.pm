#==========================================================
# SupportSQL Module - http://supportsql.com/
# Project: PerlMyAdmin
# Module:  WO::Template.pm
# Author:  Paul Wilson
# $Id:     Template.pm,v 1.00 2002/08/20 01:41:22 paul Exp $
#
# Copyright (c) 2002, SupportSQL.  All Rights Reserved.
#==========================================================
# Description:
# Tempalte Parsing Module.
#==========================================================

  package WO::Template;
#==========================================================

  use strict;
  use 5.004_04;
  use WO::Base;
  use MyAdmin::Config;
  use vars qw/$ERRORS @ISA $ATTR $VERSION/;
  @ISA = qw/WO::Base/;

  $VERSION = sprintf "%d.%03d", q$Revision: 1.00 $ =~ /(\d+)\.(\d+)/;
  $ATTR    = { 
                begin     => '<%', 
                end       => '%>', 
                root      => $CFG->{path} . '/' . 'templates', 
                inc_root  => $CFG->{path} . '/' . 'templates',
                inc_depth => 5,
                TAGS      => {},
                GLB       => {}
  };
                
  $ERRORS  = { 
                'READ'      => 'Unable to read template: %s. Reason: Does not exist or is not readable',
                'CANTELSE'  => 'else tag cannot go here!',
                'CANTEND'   => '%s tag cannot go here!',
                'CANTGLOB'  => 'Unable to load globals file %s. Reason: %s',
                'CANTCODE'  => 'Unable to evaluate template. Reason: %s',
                'CANTINC'   => 'Unable to include %s. Reason: Does not exist or is not readable',
                'INCDEPTH'  => 'Unable to include %s. Reason: Too many nested includes',
                'UNKNOWN'   => 'Unknown tag: %s',
                'LOOPON'    => 'Unable to loop. Reason: There is already an active loop',
                'LOOPREF'   => 'Unable to loop %s. Reason: Not an array reference',
                'BADLOOP'   => 'Missing endloop tag',
                'CANTELSIF' => '%s tag cannot go here!',
                'BADTAG'    => 'Bad formatting: %s',
                'UNMATCHED' => 'Unmatched if tag'
  };

#==========================================================

sub new {
#----------------------------------------------------------
# Create a new $TPL object.

    return bless ($ATTR, shift);
}

sub parse {
#----------------------------------------------------------
# Parse a template.

    my $self = shift;
    my $tpl  = shift;
    my $path = $self->{root} . '/' . $tpl . '.html';
    my $str  = $self->load($path);

# Tags must be global.
    $self->{TAGS} = shift;

# Globals are global too d:-)
    $self->load_globals;

# Do some nifty parsing.
    return $self->parse_tags($str);

}

sub parse_tags {
#----------------------------------------------------------
# Actually parse out any tags we find.
# Decided against strict formatting...too much effort.

    my $self   = shift;
    my $str    = shift;
    my $eval   = qq|local \$^W;\n\nmy \$self = shift;\nmy \$return = '';\nmy \$orig = '';\n\n|;
    my $beg    = $self->{begin};
    my $end    = $self->{end};
    my $last   = 0;
    my $endif  = 0;
    my $else   = 0;
    my $loopon = 0;
    my $tab    = '    ';
    my $depth  = 0;
    my $build  = sub { 
                 $eval .= qq{print q~} . $self->escape($_[0]) . qq{~;\n}; 
    };

# Begin looping.
    while ($str =~ /($beg\s*((?:--)?\s*(.+?)\s*(?:--)?)\s*$end)/g) {

# Set some options like the current position and tag value.
		my ($all, $max, $tag) = ($1, $2, $3);
        my ($len)             = length($all);
        my ($start)           = $last;
        $last                 = pos $str;

# Make sure we add the leading html to the output.
	    $build->( substr($str, $start, $last - $len - $start) );

# Start by stripping out tag style comments like <%-- My Comment --%>
        if (substr($max, 0, 2) eq '--' and substr($max, -2, 2) eq '--') {
            next;
	    }

# Lets now move on to basic tags with no spaces.
        if ($tag !~ /\s/) {
            if ($tag eq 'else') {
                if ($else) {
                    $eval .= qq|\n}\nelse {\n$tab|;
                    $else--;
                }
                else {
                    $build->( $ERRORS->{CANTELSE} );
                    next;
                }
            }

# Now end tags.
            elsif ($tag eq 'endif' or $tag eq 'endunless' or $tag eq 'endifnot') {
                if ($endif) {
                    $eval .= qq|}\n|;
                    $endif--;
                    next;
                }
                else {
                    $build->( sprintf($ERRORS->{CANTEND}, $tag) );
                    next;
                }
            }

# endloop tags. Only permitted in $loopon is greater than zero.
			elsif ($tag eq 'endloop') {
				if ($loopon) {
					$eval .= q|      }|;
					$eval .= q|    }|;
					$eval .= q|  }|;
					$eval .= q|  $self->{TAGS} = $orig;|;
					$eval .= q|}|;
                    $loopon = 0;
					next;
				}
				else {
					$build->( sprintf($ERRORS->{CANTLOOP}, $tag) );
					next;
				}
			}

# Any left over tags without spaces. If inside a loop just build the output, don't compile (yet!).
            else {
                $eval .= $loopon ? qq|print \$self->escape(\$self->basic_tag('$tag'));\n| : qq|print q~@{ [ $self->escape($self->basic_tag($tag)) ] }~;\n|;
                next;
            }
        }

# Tags with spaces.
		else {

# Start with include tags. <%include foo.html%>
            if ($tag =~ m,^include\s+([\w\.]+)$,) { 
				my $file = $1;
                my $path = $self->{root} . '/' . $file;
                my $inc;

# Make sure the include exists and is readable.
			    if (! -e $path and ! -r _) {
					$build->( sprintf($ERRORS->{CANTINC}, $path) );
					next;
				}
				else {

# Prevent too many nested includes.
					if ($depth > $self->{inc_depth}) {
						$build->( $ERRORS->{INCDEPTH} );
						next;
					}
					else {
						$inc = $self->load($path);
                        substr($str, $last - $len, $len) = $inc;
                        $last -= $len;
                        pos($str) = $last;
                        $depth++;
					    next;
				    }
			    }
		    }

# Loop tags <%loop me%>. Only if $loopon = 0
            elsif ($tag =~ /^loop\s+(\w+)$/) {
				my $loop = $1;
                if (! $loopon) {
				   if (ref $self->{TAGS}->{$loop} ne 'ARRAY') {
					   $build->( sprintf($ERRORS->{LOOPREF}, $loop) );
					   next;
				   }
				   else {
					   $eval .= $self->loop_me($loop);
					   $loopon = 1;
					   next;
				   }
                }

# Nested loop?
                else {
                    $build->( $ERRORS->{LOOPON} );
                    next;
                }
			}

# if/unless type tags. <%unless foo%> <%if bar%>
			elsif ($tag =~ /^(unless|if|elsif|ifnot)\s+(.+)$/i) {
				my ($type, $cond) = ($1, $2);

# If the type is ifnot, we need to convert this to perl code.
			    $type eq 'ifnot' and $type = 'unless';

# If we found an elsif but $endif is 0 then the tag isn't allowed here.
				if ($type eq 'elsif' and ! $endif) {
					$build->( sprintf($ERRORS->{CANTELSIF}, $type) );
					next;
				}
                elsif (index($cond, ' ') == -1 and index($cond, "'") == -1) {
					$eval .= qq|\n}| if $type eq 'elsif';
					$eval .= qq|\n$type (\$self->{TAGS}->{'$cond'}) {\n$tab|;
					unless ($type eq 'elsif') {
						$endif++; $else++;
					}
					next;
				}

# Now conditional tags with spaces.
				else {
                    my $comparison = $self->comparison($cond);
					if (! $comparison) {
						$build->( sprintf($ERRORS->{BADTAG}, $cond) );
						next;
					}
					else {
					   $eval .= qq|}| if $type eq 'elsif';
					   $eval .= qq|$type ($comparison) {\n$tab|;
					   unless ($type eq 'elsif') {
						   $endif++; $else++;
					   }
					   next;
					}
				}
			}

# Anything left over is bad :(
            else {
				$build->( sprintf($ERRORS->{UNKNOWN}, $tag) );
			    next;
			}
        }
    }

# If $ifs is greater than 0 then we have unmatched tags so close them off.
    if ($endif > 0) {
		$eval .= qq|}\n| for (1..$endif);
        $build->( $ERRORS->{UNMATCHED} );
    }

# We need to close open loops to stop errors.
    if ($loopon) {
        $eval .= qq|}}}}\n|;
        $build->( $ERRORS->{BADLOOP} );
        $loopon = 0;
    }

# Now add the trailing html on to the output.
    $build->( substr($str, $last) );

    return $self->eval($eval);
}

sub loop_me {
#----------------------------------------------------------
# Parse loop tags.

	my ($self, $loop) = @_;
    my ($var)         = q|$self->{TAGS}->{'| . $self->escape($loop) . q|'}|;
    my ($return)      = qq|
        \{ 
		 \$orig = \$self->{TAGS};
         RUN: \{
         my \$to_loop  = $var;
		 my \$loop_iter = 0;
         if (ref \$to_loop eq 'ARRAY') {
            my \$next;
            my \$i = 0;
            my \$now = \$to_loop->[\$i++];
            ref \$now eq 'HASH' or next;
            while (\$now) {
                   \$next = \$to_loop->[\$i++];
                   ref \$now eq 'HASH' or last RUN;
				   \$now->{loop_iteration} = ++\$loop_iter;
                   \$self->{TAGS}          = \$now;
                   \$now                   = \$next;
|;

    return $return;
}

sub comparison {
#----------------------------------------------------------
# This routine will try to parse comparisons.
# eg <%if foo and bar and blech%> or <%if foo > '1' or bar < '10'%>
# They must be kept seperate. You can't do:
# <%if foo and bar or blech > '6'%> and you can't use or/and in the same tag.

    my ($self, $comp) = @_;
    my ($output);

# Simple <%if foo and bar%>
    if ($comp =~ /^\w+\s+(and|or)\s+\w+/) {

# Split the bool leaving each tag.
        my $bool = $1;
	    my @bool = split /\s+$bool\s+/, $comp;

# Remove anything unwanted.
	    @bool = grep /^\w+$/, @bool;

# Build the output.
	    $output = join " $bool ", map { "\$self->{TAGS}->{'$_'}" } @bool;
        return $output;
    }

# Comparison/and <%if foo > '1' and bar == '5'%>
    elsif ($comp =~ /^\w+\s+([=!]=|<|>|[lg]t|[gl]e|ne|eq|%|<=|>=)\s+'?\w+'?\s*(\s+(and|or)\s+.+|)$/) {
           my $bool = $3;
           my @comp = split /\s+$bool\s+/, $comp;

# Get rid of nasties.
	       @comp = grep !/[`~\\\/\$^&\*()\[\]{}"£|¬\?\.,#@;:\+\-]/, @comp;
	       for (@comp) {
		       my @cond = split /\s+/;
		       $output .= qq|\$self->{TAGS}->{'$cond[0]'} $cond[1] |;
		       if ($cond[2] =~ /^'(\w+)'$/) {
		           $output .= qq|'$1'|;
		       }
		       else {
		           $cond[2] =~ s/'//g;
		           $output .= qq|\$self->{TAGS}->{'$cond[2]'}|;
		       }
		       $output .= qq| $bool |;
           }

# Trim off remaining bool.
           $output =~ s/\s*$bool\s*$//;
	       return $output;
    }

    return 0;
}

sub eval {
#----------------------------------------------------------
# Evaluate the template code.

    my $self = shift;
    my $eval = shift;
    
    my $code = eval "sub { $eval };";
    
    return ref $code eq 'CODE' ? $code->($self) : $self->error($ERRORS->{CANTCODE}, $@, 1);
}

sub basic_tag {
#----------------------------------------------------------
# Parse a basic tag.

    my ($self, $tag) = @_;
	my ($code);

# A normal tag.
    if (exists $self->{TAGS}->{$tag}) {
		return $self->{TAGS}->{$tag};
    }

# A code reference global.
	elsif (exists $self->{GLB}->{$tag}) {
		if (substr($self->{GLB}->{$tag}, 0, 5) eq 'sub {') {
     		local $SIG{__DIE__};
			$code = eval "$self->{GLB}->{$tag}";
			return ref $code eq 'CODE' ? $code->($self) : $@;
		}

# A normal global.
		else {
		    return $self->escape($self->{GLB}->{$tag});
		}
	}

# Unknown.
	else {
		return sprintf($ERRORS->{UNKNOWN}, $tag);
	}
}

sub load {
#----------------------------------------------------------
# Load a template into a string.

    my $self = shift;
    my $path = shift;
    my $str  = '';

# The template doesn't exist or isn't writable.
    (-e $path and -r _) or return $self->error($ERRORS->{READ}, $path, 1);

# Read the template into a string. do{} is less intensive than read()
    open TPL, $path or return $self->error($ERRORS->{OPEN}, [$path, $!], 1);
    $str = do { local $/; <TPL> };
    close TPL;

    return $str;
}

sub load_globals {
#----------------------------------------------------------
# Load the globals file.

    my ($self)   = shift;
	my ($path)   = $self->{root} . '/' . 'globals.txt';
    $self->{GLB} = do $path or return $self->error( $ERRORS->{CANTGLOB}, [$path, $!], 1);
	return 1;
}

sub escape {
#----------------------------------------------------------
# Escape anything that will break the code.

    my $self = shift;
    my $code = shift;

# Escape the tildas.
    $code =~ s/~/\\~/g;

    return $code;
}

1;