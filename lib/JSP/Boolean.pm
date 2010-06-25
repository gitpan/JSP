package JSP::Boolean;

use strict;
use warnings;

use overload 
    'bool' => sub { ${$_[0]} },
    fallback => 1;

1;
__END__

=head1 NAME

JSP::Boolean - Perl class that encapsulates the javascript's C<true> and
C<false> values.

=head1 DESCRIPTION

In javascript, every boolean expression results in one of the two values
C<true> or C<false>.  Both values, when returned to perl space will be wrapped
as instances of JSP::Boolean.  Both perl objects use the C<overload>
mechanism to behave as expected.

As in javascript the rules to convert other values to boolean values are
similar to perl's ones, you seldom need to think about them. But, although is
considered bad style, you can found javascript code that uses something like the
following:

    function foo(val) {
	if(val === true) {
	    ...
	}
    }

So the need arises to be able to generate true javascript boolean values from perl. In those cases you can use the class methods described next.

=head1 Class methods

=over 4

=item True

Return an object that when passed to javascript results in the C<true> value,
and when evaluated in a perl expression gives a TRUE value.

    my $realJStrue = JSP::Boolean->True;

The same object that constant L<JSP/JS_TRUE>.

=item False

Return an object that when passed to javascript results in the C<false> value,
and when evaluated in a perl expression gives a FALSE value.

    my $realJSfalse = JSP::Boolean->False;

The same object that constant L<JSP/JS_FALSE>.

=back
