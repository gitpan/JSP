#!/usr/bin/perl
use strict;
use warnings;

use JSP;

warn "$$\n";

my $cx = JSP->stock_context();
# For JS V2.0 be two orders of magnitude bigger.

$cx->bind_function(returns_array_ref => sub { return [1 .. 100]; });

{
    $cx->eval(q/
for (var i = 0; i < 2000001; i++) {
    var v = returns_array_ref();
    if(i % 10000 == 0)
        say("Created " + i + " array refs");
}
/);
}

# Wait for ok
<>;
