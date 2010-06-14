use strict;
use warnings;
use Exporter;
use MyAdmin::Config;
use Test::Base tests =>1;

isa_ok( $MyAdmin::Config::CFG, "HASH");


