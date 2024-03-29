package JSP::Runtime;
use strict;
use warnings;

use Carp;

require JSP::Context;
require JSP::Error;
require JSP::Function;
require JSP::Array;
require JSP::Controller;

our @ISA = qw(JSP::RawRT);
our $MAXBYTES = 1024 ** 2 * 4;
our %Plugins = ();

sub new {
    my $pkg = shift;
    bless JSP::RawRT::create(shift || $MAXBYTES);
}

sub create_context {
    my $self = shift;
    my $plugin = shift;
    my $ctx = JSP::Context->new($self);
    if($plugin) {
	if($Plugins{$plugin}) {
	    $Plugins{$plugin}->($ctx);
	} else {
	    croak "No plugin '$plugin' installed\n";
	}
    }
    return $ctx;
}

my $stock_ctx;
sub JSP::stock_context {
    my($pkg, $stock) = @_;
    my $clone;
    if(!defined $stock_ctx) {
	$stock ||= 'stock';
	require JSP::Runtime::Stock if $stock eq 'stock';
	my $rt = __PACKAGE__->new();
	$clone = $stock_ctx = $rt->create_context($stock);
	Scalar::Util::weaken($stock_ctx);
    } else {
	$clone = $stock_ctx;
    }
    return $clone;
}

1;

__END__

=head1 NAME

JSP::Runtime - Runs contexts

=head1 SYNOPSIS

    use JSP;

    my $rt = JSP::Runtime->new();
    my $ctx = $rt->create_context();

    # BTW, if you don't need the runtime, it is always easier to just:

    use JSP;

    my $ctx = JSP->stock_context();

=head1 DESCRIPTION

In SpiderMonkey, a I<runtime> is the data structure that holds javascript
variables, objects, script and contexts. Every application needs to have
a runtime. This class encapsulates the SpiderMonkey runtime object.

The main use of a runtime in JSP is to create I<contexts>, i.e. L<JSP::Context>
instances.

=head1 INTERFACE

=head2 CLASS METHODS

=over 4

=item new ( [ $maxbytes] )

Creates a new C<JSP::Runtime> object and returns it.

If the I<$maxbytes> option is given, it's taken to be the number of bytes that
can be allocated before garbage collection is run. If omitted defaults to 4MB.

=back

=head2 INSTANCE METHODS

=over 4

=item create_context ()

Creates a new C<JSP::Context> object in the runtime. 

=back

=head2 PACKAGE VARIABLES

=over 4

=item $MAXBYTES

The default max number of bytes that can be allocated before garbage collection is run.
Used when you don't pass a I<$maxbytes> parameter to L</new>.

Useful to set the default before you call L<JSP/stock_context>.

=back

=cut
