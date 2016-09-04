package MVC::Neaf::Exception;

use strict;
use warnings;
our $VERSION = 0.0501;

=head1 NAME

MVC::Neaf::Exception - Exception class for Not Even A Framework.

=head1 DESCRIPTION

=head1 EXPORT

This module exports one function: C<neaf_err>.
It may be useful if one intends to use
a lot of try/catch blocks in the controller.

=cut

use Scalar::Util qw(blessed);
use parent qw(Exporter);
use overload '""' => "as_string";

our @EXPORT_OK = qw(neaf_err);

=head2 neaf_err( $@ )

Rethrow immediately if given an MVC::Neaf::Exception object,
do nothing otherwise.

Returns nothing.

This may be useful if one has a lot of nested subs/evals
and plans to utilize Neaf::Request redirect or error methods
from within.

=cut

sub neaf_err {
    return unless blessed $_[0] and $_[0]->isa(__PACKAGE__);
    die $_[0];
};

=head1 METHODS

=head2 new( 500 )

=head2 new( %options )

Returns a new exception object.

=cut

sub new {
    my $class = shift;
    my %opt = @_ == 1 ? ( -status => @_ ) : @_;

    $opt{-status} ||= 500;

    return bless \%opt, $class;
};

=head2 as_string()

Stringify. Result is guaranteed to start with MVC::Neaf.

=cut

sub as_string {
    my $self = shift;

    return "MVC::Neaf redirect: see $self->{-location}"
        if $self->{-status} eq 302 and $self->{-location};
    return "MVC::Neaf error $self->{-status}"
        .( $self->{message} ? ": $self->{message}" : "");
};

=head2 TO_JSON()

Converts exception to JSON, so that it doesn't frighten View::JS.

=cut

sub TO_JSON {
    my $self = shift;
    return { %$self };
};

1;
