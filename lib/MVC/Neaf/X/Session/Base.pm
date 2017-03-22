package MVC::Neaf::X::Session::Base;

use strict;
use warnings;
our $VERSION = 0.1501;

=head1 DESCRIPTION

MVC::Neaf::X::Session::Base - session engine base class & tooling for
Not Even A Framework.

=head1 SINOPSYS

    package My::Session::Engine;
    use parent qw(MVC::Neaf::X::Session::Base);

    sub store { ... };
    sub fetch { ... };

    1;

=head1 METHODS

=cut

use parent qw(MVC::Neaf::X::Session);
use JSON;
use Carp;


=head2 new( %options )

%options may include:

=over

=item * session_ttl - how long until session expires (not given = don't expire).

=item * session_renewal_ttl - how long until session is forcibly re-saved
and updated.
Defaults to session_ttl * some_fraction.
0 means don't do this at all.

=back

=cut

sub new {
    my $class = shift;

    my $self = $class->SUPER::new( @_ );

    if (!defined $self->{session_renewal_ttl}) {
        my $ttl = $self->session_ttl;
        $self->{session_renewal_ttl} = ($ttl || 0) * 0.625;
    };

    return $self;
};

=head2 save_session( $id, $hash )

Save session data. Returns hash with keys id and expire.
Returned id MAY differ from the given one, and must be honored in such case.

=cut

sub save_session {
    my ($self, $id, $obj) = @_;

    my $str  =   $self->encode( $obj );
    $id      ||= $self->get_session_id;

    my $hash = $self->store( $id, $str, $obj );

    $hash->{id} ||= $id;
    $hash->{expire} ||= $self->get_expire;

    return $hash;
};

=head2 load_session( $id )

Load session by id. A hash containing session data, id, and expiration
time is returned.

Session is re-saved if time has come to update it.

=cut

sub load_session {
    my ($self, $id) = @_;

    my $hash = $self->fetch( $id );
    return unless ref $hash eq 'HASH' and $hash->{data};

    $hash->{data} = $self->decode( $hash->{data} );
    return unless $hash->{data};

    # expired = return empty & cleanup
    if ($hash->{expire} and $hash->{expire} < time ) {
        $self->delete_session( $id );
        return;
    };

    if ($self->need_renewal( $hash->{expire} )) {
        my $update = $self->save_session( $id, $hash->{data} );
        $hash->{id} = $update->{id} || $id;
        $hash->{expire} = $update->{expire} || $self->get_expire;
    };

    # just return fetched data
    return $hash;
};

=head2 get_expire ( $time || time )

Caclulate expiration time, if applicable.

=cut

sub get_expire {
    my ($self, $time) = @_;
    $time = time unless defined $time;

    my $ttl = $self->session_ttl;
    return $ttl ? $time + $ttl : ();
};

=head2 need_renewal( $time )

Tell if session expiring by $time needs to be renewed.

=cut

sub need_renewal {
    my ($self, $time) = @_;

    my $ttl = $self->session_renewal_ttl;

    return ($time && $ttl) ? ($time < time + $ttl) : ('');
};

=head2 session_renewal_ttl

Renewal ttl.

=cut

sub session_renewal_ttl {
    my $self = shift;
    return $self->{renewal_ttl};
};

=head2 encode

=cut

sub encode {
    my ($self, $data) = @_;
    my $str = eval { encode_json( $data ) };
    carp "Failed to encode session data: $@"
        if $@;
    return $str;
};

=head2 decode

=cut

sub decode {
    my ($self, $data) = @_;
    my $obj = eval { decode_json( $data ) };
    carp "Failed to encode session data: $@"
        if $@;
    return $obj;
};

=head2 fetch ($id)

Stub, to be redefined by real storage access method.
Return is expected as { data => stringified_session }.

=cut

sub fetch {
    my ($self, $id) = @_;

    $self->my_croak("unimplemented");
};

=head2 store( $id, $stringified_data, $data_as_is)

Stub, to be redefined by real storage access method.
Return is expected as { id => some_id, expire => unix_time }.

=cut

sub store {
    my ($self, $id, $data_str, $data_real) = @_;

    $self->my_croak("unimplemented");
};

1;
