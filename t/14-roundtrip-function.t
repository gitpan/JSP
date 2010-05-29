#!perl
use strict;
use warnings;

use JSP;
use Test::More tests => 7;

my $rt = JSP::Runtime->new;
{
    my $cx = $rt->create_context;
    $cx->bind_function('ok' => \&ok);
    my $foo = $cx->eval(q|function() { return 1 };|);
    isa_ok($foo, 'JSP::Function');
    is($cx->call($foo), 1, 'I can call it');
    is($foo->(), 1, 'As a coderef too');

    my $bar = $cx->eval(q|
	function(fun) { 
	    ok( fun(), "should have roundtripped"); 
	};
    |);
    isa_ok($bar, 'JSP::Function');
    $cx->call($bar, $foo);
    $bar->($foo);
}
ok(1, "All done, clean");
