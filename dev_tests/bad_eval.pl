#!/usr/bin/perl

use JSP;

my $rt = JSP::Runtime->new();
my $cx = $rt->create_context();
$cx->{RaiseExceptions} = 0;
$cx->eval( "foo } bar {" );
warn $@;

