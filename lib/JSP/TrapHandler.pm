package JSP::TrapHandler;
use strict;
use warnings;

use JSP;
JSP::_boot_(__PACKAGE__);

sub JSP::RawRT::set_interrupt_handler {
    my ($self, $callback, $data) = @_;
    $callback = scalar(caller)->can($callback) if $callback &&  !ref $callback;
    if($callback) {
	croak("Callback not a code ref!") unless ref $callback eq 'CODE';
        $self->add_interrupt_handler(JSP::TrapHandler->new($callback, $data));
    } else {
        $self->remove_interrupt_handler();
    }
}

1;

__END__

=head1 NAME

JSP::TrapHandler - Add support for Traps Handling to JSP

=over 4

=item new ( $code, $data )

Construct a new closure with $code and $data
