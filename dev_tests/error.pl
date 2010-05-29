#!/usr/bin/perl 
use strict;
use warnings;

use JSP;

my $ctx = JSP->stock_context;

eval {
    $ctx->eval(q{
	say("Hello");
	throw new Error("Whoops!"); // Synthesize a runtime error
	say("Goodby"); // Not reached
    });
};
if($@) {
    print $@->toString(), " ($@)\n";
}

