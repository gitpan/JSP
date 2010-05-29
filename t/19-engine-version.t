#!perl

use Test::More tests => 7;

use strict;
use warnings;

use JSP;

my $iver = JSP::get_internal_version;
ok($iver);
diag("Version: $iver");

my $str = JSP->get_engine_version();
like($str, qr/JavaScript-C/, "Scalar get_engine_version");
like($str, qr/\b\d+\.\d+\b/);
like($str, qr/\b\d+-\d+-\d+\b/);
diag($str);

my ($engine, $version, $build_date) = JSP->get_engine_version(); 
is($engine, "JavaScript-C");
like($version, qr/\b\d+\.\d+\b/);
like($build_date, qr/\b\d+-\d+-\d+\b/);
