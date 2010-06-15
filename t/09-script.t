#!perl

use Test::More tests => 13;

use strict;
use warnings;

use JSP;

# Create a new runtime
my $rt1 = JSP::Runtime->new();
my $cx1 = $rt1->create_context();

# Compile a script
my $script = $cx1->compile(q!
  var v = Math.random(10);
  v + 1;
!);

isa_ok($script, "JSP::Script", "Compile returns object");
#Developer's sanity tests
my($c, $i) = unpack('Cn', $script->_prolog);
is($c, 127, "Prolog ok");
is($script->_getatom($i), 'v', "Declares v");

# Run the script
for(1 .. 10) {
    ok($script->exec > 0, "Ok pass $_");
}
