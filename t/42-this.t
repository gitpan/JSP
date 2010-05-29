#!perl

use strict;
use warnings;

use Test::More tests => 10;                      # last test to print

use JSP;

{
    my $ctx = JSP::Runtime->new->create_context();
    $ctx->bind_function(check_this => sub {
	is($JSP::This, tied %{$_[0]}, "This match $_[1]");
	is($JSP::This->CLASS_NAME, $_[2], "Expected class $_[2]");
    });

    ok(!$JSP::This, "No 'this' yet");
    $ctx->eval(q| check_this(this, "when global", 'global') |);
    $ctx->eval(q| check_this.call(this, this, "call global", 'global') |);
    $ctx->eval(q| check_this.apply(this, ["call global", 'global'] ) |);
    $ctx->eval(q| foo = {}; foo.check = check_this; |);
    $ctx->eval(q| foo.check(foo, "when object", 'Object'); |);
    ok(!$JSP::This, "Not 'this' now");
}
