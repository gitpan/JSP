#!/usr/bin/perl

use strict;
use warnings;

use Devel::Peek qw(Dump);
use JSP;

my $v = {};

my $rt = JSP::Runtime->new();
my $cx = $rt->create_context();

$cx->bind_function('dump' => sub { my $y = shift; warn "Got a $y\n" });
$cx->call('dump' => {});

