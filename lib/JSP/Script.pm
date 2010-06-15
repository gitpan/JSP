package JSP::Script;

use strict;
use warnings;

our @ISA = qw(JSP::Boxed);

sub new {
    my $pkg = shift;
    jss_compile(@_);
}

sub exec {
    my($self, $gobj) = @_;
    
    jss_execute($self->__context, $gobj, $self->__content);
}

sub _prolog {
    my($self) = @_;
    my $pp = jss_prolog($self->__context, $self->__content);
    return $$pp;
}

sub _getatom {
    my($self, $index) = @_;
    return jss_getatom($self->__context, $self->__content, $index);
}

$JSP::ClassMap{Script} = __PACKAGE__;

1;
__END__

=head1 NAME

JSP::Script - Encapsulates pre-compiled javascript code.

=head1 DESCRIPTION

If you have a big script that has to be executed over and over again
compilation time may be significant.  The method C<compile> in
C<JSP::Context> provides a mean of returning a pre-compiled script which
is an instance of this class which can be executed without the need of
compilation.

=head1 PERL INTERFACE

=head2 INSTANCE METHODS

=over 4

=item exec

Executes the script and returns the result of the last statement.

=back

=begin PRIVATE

=head1 PRIVATE INTERFACE

=over 4

=item new ( $context, $gobj, $source, $name )

Creates a new script in context.

=item jss_compile ( PJS_Context *pcx, SV *gobj, SV *source, const char *name = "" )

Compiles a script and returns a C<JSP::Script>

=item jss_execute ( PJS_Context *pcx, SV *gobj, JSObject *obj)

Executes the script wrapped in obj in the context pcx in the scope of gobj

=item jss_prolog ( JSP::Context pcx, JSP::RawObj, name,  sps)

Returns the prolog bytecode of the script wrapped in obj

=item jss_getatom ( JSP::Context pcx,  JSP::RawOb obj, int index)

Returns the atom at index in script

=back

=end PRIVATE

=cut

