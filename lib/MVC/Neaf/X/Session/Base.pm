package MVC::Neaf::X::Session::Base;

use strict;
use warnings;
our $VERSION = 0.1402;

=head1 NAME

MVC::Neaf::X::Session::Base - base class for Neaf session objects.

=head1 DESCRIPTION

While L<MVC::Neaf::X::Session> provides a clear API for sessions,
it lacks some basic primitives for simple and straightforward implementation.

Use this class for its helper functions.

The API is as follows:

=head1 SYNOPSIS

    package My::Session;
    use parent qw(MVC::Neaf::X::Session::Base);

    sub store {
        my ($self, $id, $string) = @_;
        return { id => ..., expire => ... };
    };

    sub fetch {
        my ($self, $id) = @_;

        return { id => ..., data => ..., expire => ... };
    };

=head1 METHODS

=cut

use Carp;
use JSON;

use parent qw(MVC::Neaf::X::Session);

=head2 encode( \%data )

Stringify given data. Currently uses JSON.

=cut

sub encode {
    my ($self, $data) = @_;
    $data = eval { encode_json($data) };
    carp "Failed to save session data: $@" if $@;
    return $data;
};

=head2 decode( $string )

The reverse of encode.

=cut

sub decode {
    my ($self, $data) = @_;
    $data = eval { decode_json($data) };
    carp "Failed to load session data: $@" if $@;
    return $data;
};

=head2 save_session( $id, $data )

Save a session. This uses C<encode> and C<store> functions.

=cut

sub save_session {
    my ($self, $id, $data) = @_;

    my $enc = $self->encode( $data );
    return unless $enc;

    my $ret = $self->store( $enc, $id );
    return unless $ret;

    $self->my_croak( "Wrong return type from store(): ".(ref $ret || 'SCALAR') )
        unless ref $ret eq 'HASH';

    $ret->{expire} ||= $self->make_expire;
    $ret->{id} ||= $id;
    return $ret;
};

=head2 load_session( $id )

Load a session using C<fetch> and C<decode>.
Also the session will be refreshed if expiration date is approaching.
This is controlled by C<session_renewal> new() parameter.
Set to 0 to avoid renewal.

=cut

sub load_session {
    my ($self, $id) = @_;

    my $raw = $self->fetch( $id );
    return unless $raw;

    $self->my_croak( "Wrong return type from fetch(): ".(ref $raw || 'SCALAR') )
        unless ref $raw eq 'HASH';

    my $data = $self->decode( $raw->{data} );
    return unless $data;

    # prolong session if it ends too soon
    if (!$raw->{id} and $raw->{expire}
        and $raw->{expire} < $self->make_renewal
    ) {
        my $update = $self->store( $id, $data );
        if ($update and ref $update eq 'HASH') {
            $raw->{id} = $update->{id} || $id;
            $raw->{expire} = $update->{expire} || $self->make_expire;
        };
    };

    $raw->{data} = $data;
    return $raw;
};

=head2 store( $id, $stringified_data )

Save data to storage.
Needs to be implemented in subclass.

=cut

sub store {
    my $self = shift;
    $self->my_croak( "unimplemented" );
};

=head2 fetch( $id, $stringified_data )

Load stringified data from storage.
Needs to be implemented in subclass.

=cut

sub fetch {
    my $self = shift;
    $self->my_croak( "unimplemented" );
};

1;
