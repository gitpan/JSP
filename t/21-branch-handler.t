#!perl

use Test::More;

use strict;
use warnings;

use JSP;
if(defined &JSP::Context::jsc_set_branch_handler) {
    plan tests => 3;
} else {
    plan skip_all => "No support for branch_handler in this SpiderMonkey";
}

my $called = 0;
sub branch_handler {
    $called++;
    return 1;
}

my $rt1 = JSP::Runtime->new();
my $cx1 = $rt1->create_context();

$cx1->eval("for(i = 0; i < 10; i++) {}");
is($called, 0);

$cx1->set_branch_handler(\&branch_handler);
$cx1->eval("for(i = 0; i < 10; i++) {}");
is($called, 10);

$cx1->set_branch_handler(undef);
$called = 0;
$cx1->eval("for(i = 0; i < 10; i++) {}");
is($called, 0);

