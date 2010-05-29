#!/usr/bin/perl

use strict;
use warnings;

use JSP;

my $cx = JSP->create_runtime->create_context;

$cx->bind_function(println => sub { print STDERR @_, "\n" });

$cx->eval(q{
   var pa = new PerlArray();
   pa.push(10, 20, 30);
});

