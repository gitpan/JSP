package JSP::Controller;
use strict;
use warnings;
our @ISA = qw(JSP::Object);
use Carp();

sub JSP::Context::get_controller {
    my $ctx = shift;
    my $scope = shift || $ctx->get_global;
    my $jsc;
    if($jsc = $scope->{'__PERL__'} and ref $jsc eq __PACKAGE__) {
       return $jsc;
    } else {
	die "Can't find controller\n";
    }
}

sub add {
    my $self = shift;
    my $package = shift;
    _get_stash($self->__context, $package);
}

sub added {
    my $self = shift;
    my $package = shift;
    return $self->{$package};
}

sub list {
    my $self = shift;
    return keys %{$self};
}

sub install {
    my $self = shift;
    my $inst = 0;
    no warnings 'numeric';
    while(my $bind = shift) {
	my $package = shift;
	my $con = '';
	if(ref($package) eq 'ARRAY') {
	    $con = $package->[1];
	    $package = $package->[0];
	}
	my $stash = $self->add($package);
	my $const = ref($con) eq 'CODE' ? $con : $package->can($con || 'new');
	if($const) {
	    $self->__context->bind_value($bind => $stash->set_constructor($const));
	} elsif($con == -1) {
	    $stash->package_bind($bind);
	} elsif(!$con) {
	    $stash->class_bind($bind);
	} else {
	    Carp::croak("Invalid \$mode $con in install");
	}
	$inst++;
    }
    return $inst;
}

sub secure {
    my $self = shift;
    $self->__content->seal_object($self->__context);
}

$JSP::ClassMap{perl} = __PACKAGE__;

package JSP::Stash;
our @ISA = qw(JSP::Object);

sub allow_from_js {
    my $self = shift;
    no strict 'refs';
    ${"$self->{'__PACKAGE__'}::_allow_js_export"} = shift;
}

sub class_bind {
    my $self = shift;
    $self->__context->bind_value(shift, $self);
}

sub package_bind {
    my $self = shift;
    $self->__context->bind_value(shift, $self->{Proxy});
}

sub add_properties {
    my $self = shift;
    no strict 'refs';
    local ${"$self->{'__PACKAGE__'}::_allow_js_export"} = undef;
    while(my $meth = shift) {
	$self->{$meth} = shift;
    }
    return $self;
}

sub set_constructor {
    my $self = shift;
    my $con = shift || 'new';
    my $const = ref($con) eq 'CODE' ? $con : $self->{__PACKAGE__}->can($con);
    if($const) {
	$self->{Proxy}{constructor} = $const;
    } else {
	Carp::croak("Can't find '$con' in $self->{__PACKAGE__}");
    }
    return $const;
}

package JSP::Visitor;
our @ISA = qw(JSP::Object);
use overload '%{}' => sub { tie my(%h),__PACKAGE__,$_[0]; \%h },
    fallback => 1;
sub TIEHASH { $_[1] }
sub DESTROY {} # This hasn't a passport
sub VALID { ${$_[0]}->[1] && ${$_[0]}->[1]->_isjsvis(${$_[0]}->[6]); }

package #Hide from PAUSE
    JSP::Any;

require Scalar::Util;
sub toSource {
    my $v = shift;
    my $rt = ref($v) || '';
    my $t;
    $t = tied(($rt eq 'ARRAY') ? @$v : ($rt eq 'HASH') ? %$v : $rt) if $rt;
    my $val;
    if($t && $t->isa('JSP::Object') || 
       Scalar::Util::blessed($v) && $v->isa('JSP::Object') && ($t=$v)
    ) {
	$val = $t->toSource();
    } elsif($rt) {
	for($rt) {
	    /^HASH$/ || /^JSP::PerlHash$/ and do {
		$val = JSP::PerlHash::toSource($v); last
	    };
	    /^ARRAY$/ || /^JSP::PerlArray$/ and do {
		$val = JSP::PerlArray::toSource($v); last
	    };
	    /^CODE$/ and do { $val = JSP::PerlSub::toSource($v); last };
	    $val = $rt;
	}
    } elsif(Scalar::Util::looks_like_number($v)) {
	$val = "$v";
    } else {
	$val = "'$v'";
    }
    $val;
}

package JSP::PerlScalar;

my $scalar;
our $prototype = \$scalar;

sub toString {
    my $this = shift || $JSP::This;
    "${$this}";
}

package JSP::PerlSub;

sub _const_sub { # Method call
    my $code = $_[1];
    my($package, $file, $line, $hints, $bitmask) = (caller 2)[0,1,2,8,9];
    # warn sprintf("SBB: $package,$file,$line,'$code', H: %x, BM: %s\n", $hints,$bitmask);
    my $cr = eval join("\n",
	qq|package $package;BEGIN {\$^H=$hints;\${^WARNING_BITS}="$bitmask";}|,
	"#line $line $file",
	"sub {$code}") or Carp::croak("Can't compile: $@");
    return $cr;
}

sub prototype {}
our $wantarray = 1;

sub toString {
    my $code = shift || $JSP::This;
    "sub {\n     [perl code]\n}";
}

sub toSource {
    my $code = shift || $JSP::This;
    require B::Deparse;
    return 'sub ' . B::Deparse->new()->coderef2text($code)
}

sub call {
    my $code = $JSP::This;
    local $JSP::This = shift;
    $code->(@_);
}

sub apply {
    # FIXME, semantic bug
    my $this = shift;
    my $code = $JSP::This;
    local $JSP::This = $this;
    $code->( $this, @{$_[0]} );
}

package JSP::PerlArray;
# Some of the following methods are contrived for legacy support,
# will be simplified in 2.1
sub toString {
    my $aref = $JSP::This;
    local $" = ',';
    no warnings 'uninitialized';
    return ref($aref) eq __PACKAGE__ ? "@{$$aref}" : "@{$aref}";
}

sub reverse {
    my $aref = $JSP::This;
    my $legacy = ref($aref) eq __PACKAGE__;
    my @new = reverse $legacy ? @{$$aref} : @{$aref};
    ($legacy ? ${$aref} : $aref)->[$_] = $new[$_] for(0 .. $#new);
    $aref;
}

sub sort {
    my $aref = $JSP::This;
    shift if(ref($_[0]) eq __PACKAGE__); 
    my $fun = shift;
    my $code = $fun ? sub { $fun->($a, $b) } : sub { $a cmp $b };
    my $legacy = ref($aref) eq __PACKAGE__;
    my @new = sort $code $legacy ? @{$$aref} : @{$aref};
    ($legacy ? ${$aref} : $aref)->[$_] = $new[$_] for(0 .. $#new);
    $aref;
}

sub toSource {
    my $aref = shift || $JSP::This;
    $aref = $$aref if ref($aref) eq __PACKAGE__;
    "new PerlArray(" .  join(',', map JSP::Any::toSource($_), @$aref) .  ")";
}

our @prototype=();

our $AUTOLOAD;
sub AUTOLOAD {
    my $aref = $JSP::This;
    # Best efort to disambiguate legacy mode 
    shift if(ref($_[0]) eq __PACKAGE__ && ref($_[0]) eq ref($aref));
    my $method = (split('::', $AUTOLOAD))[-1];
    my $metref = JSP::Context::current->get_global
	->{Array}->prototype->{$method};
    $metref->call($aref, @_) if($metref);
}

sub DESTROY {} # Don't autoload

*join = \&join;
*indexOf = \&indexOf;
*slice = \&slice;

package JSP::PerlHash;
our %prototype=();

sub toSource {
    my $href = shift || $JSP::This;
    my $cont = '';
    $href = $$href if ref($href) eq __PACKAGE__;
    while(my($k, $v) = each %{$href}) {
	$cont .= "'$k'," . JSP::Any::toSource($v) . ',';
    }
    chop $cont if $cont;
    "new PerlHash($cont)";
}

1;
__END__

=head1 NAME

JSP::Controller - Control which Perl namespaces can be used from javascript. 

=head1 SYNOPSIS

    use JSP;
    use Gtk2 -init;	# Load your perl modules as usual

    my $ctx = JSP->stock_context;
    my $ctl = $ctx->get_controller;
    $ctl->install(
	'Gtk2' => 'Gtk2',
	'Gtk2.Window' => 'Gtk2::Window',
	'Gtk2.Button' => 'Gtk2::Button',
        # Any more needed
    );

    $ctx->eval(q|
	var window = new Gtk2.Window('toplevel');
	var button = new Gtk2.Button('Quit');
	button.signal_connect('clicked', function() { Gtk2.main_quit() });
	window.add(button);
	window.show_all();
	Gtk2.main();
	say('Thats all folks!');
    |);

=head1 DESCRIPTION

Every context has a controller object. Context's controller object allows you to
reflect entire perl namespaces to javascript side and control how they can be used.

In the following discussion, we use the words "perl package" or simply "package" to
refer to a perl namespace, declared in perl with the keyword L<perlfunc/package>.

The controller object holds a list of every perl package exposed in some
form to javascript land. When javascript is made aware of a perl package
an instance of the special C<Stash> native class is created in the context. How
you can use that particular namespace from javascript depends on how the
C<Stash> instance or its properties are bound in javascript.

See L<JSP::Stash> for details on C<Stash> intances.

This perl class allows you to make javascript land aware of perl packages and
provides some utilities methods.
				
=head1 INTERFACE

You obtain the instance of a context's controller calling
L<JSP::Context/get_controller>.

   my $ctl = $context->get_controller;

With this you can use any of the following:

=head2 Instance methods

=over 4

=item add( $package_name )

    my $stash = $ctl->add('Foo::Bar');

Adds the package named I<$package_name> to the list of namespaces visible in
javascript, if not in there already.  Returns the L<JSP::Stash>
object that encapsulates the associated C<Stash>.

=item added ( $package_name )

    $ctl->added('Foo::Bar');

Check if the package with the given I<$package_name> is in the list of perl
namespaces visible from javascript land. Returns a TRUE value
(the L<JSP::Stash> object) if I<$package_name> is in the list, otherwise
returns a FALSE value.

Normal operation is to automatically add namespaces as needed. Packages are
added when a perl object enters javacript or you use L<JSP::Context/bind_class>
and the package isn't already known.

=item list ( )
    
    @exported = $ctl->list();

Returns a list with the names of packages available in javascript land.
    
=item install ( I<BIND_OPERATION>, ... )

Performs a serie of I<BIND_OPERATION>s in javascript land.

Every I<BIND_OPERATION> is an expresion of the form:

=over 4

I<bind> => [ I<$package>, I<$mode> ]

=back

Where I<bind> is the property name to attach the package named I<$package> and
I<$mode> is the form to perform the binding.

There are three ways to bind a package: binding as a I<constructor>, as a I<static
class> or in I<indirect form>. You choose which way to use depending on the value
you give to the I<$mode> argument:

=over 4

=item * B<STRING>

When a B<STRING> is used as I<$mode>, you want to bind a I<constructor>.
The property I<bind> in javascript will be bound to a C<PerlSub> that references
the function named B<STRING> in the perl class associated with I<$package>.
I<bind> will then be used as a constructor.

For example

    $ctl->install(Img => [ 'GD::Simple', 'new' ]);

Binds to C<Img> a javascript constructor for objects of the perl class C<GD::Simple>,
so in javascript you can write:

    myimg = new Img(400, 250);

In perl the most common name for a constructor is C<new>, as long as you known
that your perl class I<has> a constructor named C<new>, you can use a simplified
form of the I<BIND_OPERATION>:

    $ctl->install(Img => 'GD::Simple');

=item * B<undef>

When $mode is B<undef>, you want to bind the perl package as a I<static class>.
The property I<bind> in javascript will be bound to the C<Stash> itself
associated with the I<$package>. See L<JSP::Stash> for all the
implications.

You should bind in this form any perl package for which you need to make static
calls to  multiple functions (class methods).

For example:

    $ctl->install(DBI => [ 'DBI', undef ]);

Binds to C<DBI> the C<Stash> instance associated to the C<DBI> perl package,
allowing you to write in javascript:

    drivers = DBI->available_drivers();
    handle = DBI->connect(...);

In perl many packages work this way and/or provide constructors for I<other>
packages as static functions, but don't have a constructor for themselves.

If you know the perl class I<doesn't has> a constructor named C<new> you
can use the same simplified form of the I<BIND_OPERATION> above, and C<install>
will do the right thing.

    $ctl->install(DBI => 'DBI');

=item * B<-1>

When $mode is B<-1>, you want to bind the perl package in I<indirect> form.
This form allows javascript to resolve method calls on I<bind> to subroutines
defined in $package.

Using the I<indirect> form will make plain function calls to those subroutines
instead of static method calls.

For example:

    $ctl->install(Tests => [ 'Test::More', -1 ]);

Bind to C<Tests> an object allowing javascript to find all subroutines defined
in C<Test::More>. In javascript you'll write:

    Test.ok(...);
    Test.is(...);

A simple way to export to javascript a lot of new functions is to bind this way
a carefully crafted namespace.

    #!/usr/bin/perl
    # We are in 'main'
    use JSP;

    package forjsuse;
    sub foo {...};
    sub bar {...};
    sub baz {...};

    my $ctx = JSP->stock_context;
    $ctx->get_controller->install(Utils => ['forjsuse', -1]);
    
    $ctx->eval(q|
	Utils.bar(...);
    |);

An advantage of this method over using L<JSP::Context/bind_function> is
that the C<PerlSub> objects associated to your perl subroutines won't get
created in javascript until needed.

=back

To create a hierarchy of related properties you can pass to C<install> many
I<BIND_OPERATION>s as follows:

    $ctl->install(
	'Gtk2' => 'Gtk2',		 # Gtk lacks a 'new'. Binds a static class
	'Gtk2.Window' => 'Gtk2::Window', # Bind Gtk2::Window constructor
	'Gtk2.Button' => 'Gtk2::Button', # Bind Grk2::Button constructor
    );

=item secure ( )
    
    $ctl->secure();

Prevent further modifications to the controller's list. As a result no more perl
namespaces can be installed nor exported to the context.

=back
