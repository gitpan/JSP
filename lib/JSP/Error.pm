package JSP::Error;

use strict;
use warnings;
our @ISA = "JSP::Object";
$Carp::Internal{ __PACKAGE__ }++;

use overload q{""} => '_as_string',
    fallback => 1;

sub __new {
    my $self = shift;
    $self = $self->SUPER::__new(@_);
    # Must use basic JSP::Object methods, isn't tie-able yet
    my($rfn, $oln) = $self->FETCH('fileName') =~ /^(.+) line (\d+)$/;
    if($rfn) {
	$self->STORE('fileName', $rfn);
	$self->STORE('lineNumber', $self->FETCH('lineNumber') + $oln - 1);
    }
    $self;
}

sub _as_string {
    my $self = shift;
    return "$self->{message} at $self->{fileName} line $self->{lineNumber}";
}

sub message {
    $_[0]->{message};
}

sub file {
    $_[0]->{fileName};
}

sub line {
    $_[0]->{lineNumber};
}

sub stacktrace {
    my $stack = $_[0]->{stack};
    return () unless $stack;
    return map {
        /^(.*?)\@(.*?):(\d+)$/ && { function => $1, file => $2, lineno => $3 }
    } split /\n/, $stack;
}

sub new {
    my($mess, $file, $line) = @_;
    $mess ||= 'something fail';
    my $parms = "'$mess'";
    $parms .= ",'$file'" if $file || $line;
    $parms .= ",$line" if defined $line;
    JSP::Context::current()->eval(qq{ new Error($parms); });
}

1;
__END__

=head1 NAME

JSP::Error - Encapsulates errors thrown from javascript

=head1 DESCRIPTION

Javascript runtime errors result in new C<Error> objects being created and thrown.
When not handled in javascript, those objects will arrive to perl space when are
wrapped as an instance of JSP::Error and stored in C<$@>.

What happens next depends on the value of the option L<JSP::Context/RaiseExceptions>.

=over 4

=item * 

If TRUE perl generates a fatal but trappable exeption.

=item *

If FALSE the operation returns C<undef>

=back

The following shows an example:

    eval {
	$ctx->eval(q{
	    throw new Error("Whoops!"); // Synthesize a runtime error
	});
    }
    if($@) {
	print $@->toString(); # 'Error: Whoops!'
    }
	    
=head1 PERL INTERFACE

JSP::Error inherits from L<JSP::Object> so you use them as any other
javascript Object.

=head2 Constructor

In Perl you can create new JSP::Error instances, usefull when you need to
throw an exception from a perl land function called from javascript:

    die(JSP::Error->new('something fails'));

In fact, when you C<die> in perl land inside a function that is being called from
javascript and if the error (in C<$@>) is a simple perl string, it will be
converted to an <Error> instance with the equivalent to
C<< JSP::Error->new($@) >>.

So the code above is seen as if C<throw new Error('something fails');>
was executed in javascript.

=over 4

=item new($message)

=item new($message, $fileName)

=item new($message, $fileName, $lineNumber)

I<If inside perl code that is called from javascript>, C<new(...)> will contructs
a new javascript C<Error> instance, wrap it in a JSP::Error object and return it.

If called outside, it dies with the error "Not in a javascript context".

=back

=head2 Instance properties

C<Error> instances in javascript have the following properties.

=over 4

=item message

Error message

=item name

Error Name

=item fileName

Path to file that raised this error.

=item lineNumber

Line number in file that raised this error.

=item stack

Stack trace.

=back

=head2 Instance methods

The following methods are simple perl wrappers over the properties above used you like
more methods than properties.

=over 4

=item message

The cause of the exception.

=item file

The name of the file that the caused the exception.

=item line

The line number in the file that caused the exception.

=item as_string

A stringification of the exception in the format C<$message at $file line $line>

=item stacktrace

Returns the stacktrace for the exception as a list of hashrefs containing
C<function>, C<file> and C<lineno>.

=back

=head1 OVERLOADED OPERATIONS

This class overloads stringification an will return the result from the method
C<as_string>.

=cut
