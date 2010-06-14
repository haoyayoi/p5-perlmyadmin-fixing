use inc::Module::Install;
name 'PerlMyAdmin';
all_from 'lib/MyAdmin.pm';

requires 'Cwd';
requires 'FindBin::libs';
requires 'Exporter';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
