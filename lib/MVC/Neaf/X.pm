package MVC::Neaf::X;

use strict;
use warnings;
our $VERSION = 0.07;

=head1 NAME

MVC::Neaf::X - base class for Not Even A Framework extentions.

=head1 SYNOPSIS

    package MVC::Neaf::X::My::Module;
    use parent qw(MVC::Neaf::X);

    sub foo {
        my $self = shift;

        $self->my_croak("unimplemented"); # will die with package & foo prepended
    };

    1;

=head1 DESCRIPTION

Start out a Neaf extention by subclassing this class.

Some convenience methods here to help develop.

=head1 METHODS

=cut

use Carp;

=head2 new( %options )

Will happily accept any args, except for on_* -
these must be CODEREFs, or the constructor dies.

=cut

sub new {
    my ($class, %opt) = @_;

    my @bad_callback;
    foreach (keys %opt) {
        defined $opt{$_} and /^on_/ and !UNIVERSAL::isa( $opt{$_}, 'CODE' )
            and push @bad_callback, $_;
    };

    $class->my_croak("Callback args are not callable: @bad_callback")
        if @bad_callback;

    return bless \%opt, $class;
};

=head2 backend_call( name => @args )

Try to load "on_$name" callback or "do_$name" method.
Dies if neither is found.

After that self and the rest of args are fed to that method/sub.

=cut

sub backend_call {
    my $self = shift;
    my $method = shift;

    my $todo = $self->{"on_$method"} || $self->can("do_$method");
    if (!$todo) {
        my $sub = [caller(1)]->[3];
        $sub =~ s/.*:://;
        croak join "", (ref $self || $self),"->",$sub,
            ": no backend found for $method";
    };

    return $todo->($self, @_);
};

=head2 my_croak( $message )

Like croak() from Carp, but the message is prefixed
with self's package and the name of method
in which error occurred.

=cut

sub my_croak {
    my ($self, $msg) = @_;

    my $sub = [caller(1)]->[3];
    $sub =~ s/.*:://;

    croak join "", (ref $self || $self),"->",$sub,": ",$msg;
};

1;
