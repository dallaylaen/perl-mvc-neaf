package MVC::Neaf::X::Session::Base;

use strict;
use warnings;
our $VERSION = 0.1401;

=head1 NAME

MVC::Neaf::X::Session::Storable - base class for Neaf session objects.

=head1 DESCRIPTION

While L<MVC::Neaf::X::Session> provides a clear API for sessions,
it lacks some basic primitives for simple and straightforward implementation.

=head1 METHODS

=cut

use Carp;
use JSON;

use parent qw(MVC::Neaf::X::Session);

sub encode {
    my ($self, $data) = @_;
    $data = eval { encode_json($data) };
    carp "Failed to save session data: $@" if $@;
    return $data;
};

sub decode {
    my ($self, $data) = @_;
    $data = eval { decode_json($data) };
    carp "Failed to load session data: $@" if $@;
    return $data;
};

sub save_session {
    my ($self, $id, $data) = @_;

    my $enc = $self->encode( $data );
    return unless $enc;

    my $ret = $self->store( $enc, $id );
    return unless $ret;

    $self->my_croak( "Wrong return type from store(): ".(ref $ret || 'SCALAR') )
        unless ref $ret eq 'HASH';
    return $ret;
};

sub load_session {
    my ($self, $id) = @_;

    my $raw = $self->fetch( $id );
    return unless $raw;

    $self->my_croak( "Wrong return type from fetch(): ".(ref $raw || 'SCALAR') )
        unless ref $raw eq 'HASH';

    $raw->{data} = $self->decode( $raw->{data} );
    return unless $raw->{data};

    # time to session if ends too soon
    if (!$raw->{id} and $raw->{expire}
        and $raw->{expire} < time + $self->{session_renewal}
    ) {
        $self->refresh( $id ) and $raw->{id} = $id;
    };

    return $raw;
};

sub refresh { 0 };

sub store {
    my $self = shift;
    $self->my_croak( "unimplemented" );
};

sub fetch {
    my $self = shift;
    $self->my_croak( "unimplemented" );
};

1;
