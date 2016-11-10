package MVC::Neaf::X::Session::Cookie;

use strict;
use warnings;
our $VERSION = 0.1101;

=head1 NAME

MVC::Neaf::X::Session::Cookie - Stateless encrypted cookie-based storage
for Not Even A Framework.

=head1 DESCRIPTION

Keep user session data without the need to store them on the server.

Data is instead encrypted and packed into cookies.

=head1 SYNOPSIS

    use strict;
    use warnings;
    use MVC::Neaf;
    use MVC::Neaf::X::Session::Cookie;

    my $session_engine = MVC::Neaf::X::Session::Cookie->new (
        key => 'My encryption key',
        session_ttl => 60*60*24,
    );

    MVC::Neaf->set_session_handler(
        engine => $session_engine,
    );

=head1 METHODS

See L<MVC::Neaf::X::Session> for API details.

All data is JSON-encoded, due to heavy usage of JSON elsewhere
in the framework.

=cut

use JSON::XS;
use MIME::Base64 qw(encode_base64 decode_base64);

use parent qw(MVC::Neaf::X::Session);

=head2 new

=cut

=head2 save_session( $id, $data )

Return a new id (ignoring the given one) in { id => ... }

Id is really serialized and encrypted session data
to be stored on user agent side.

B<NOTE> Currently JSON is being used, so blessed objects may NOT come back
as one expects. This MAY change in the future.

=head2 load_session( $id )

Unencrypt and deserialize session data into a perl structure again.

Returns { data => ... } as hashref.

=cut

sub save_session {
    my ($self, $id, $data) = @_;

    my $raw = $self->serialize($data);

    return {
        id     => encode_base64($self->encrypt( $raw )),
        expire => $self->{session_ttl} && time + $self->{session_ttl},
    };
};

sub load_session {
    my ($self, $id) = @_;

    my $data = $self->decrypt( decode_base64( $id ) );
    return {
        data => $self->deserialize( $data ),
    };
};

=head2 serialize( $data_struct )

=head2 deserialize( $raw_bytes )

Serealize/deserialize session data. Currently JSON is used.
Configurable serialization methods to come.

=cut

# TODO make configurable serialize/deserialize in parent class
# TODO support non-plain values (Storable? YAML?..)

my $codec = JSON::XS->new->allow_unknown->allow_blessed->convert_blessed;
sub serialize {
    my ($self, $data) = @_;

    return $codec->encode( $data );
};

sub deserialize {
    my ($self, $data) = @_;

    return $codec->decode( $data );
};

=head2 encrypt( $plain_text )

=head2 decrypt( $cipher_text )

Encrypt/decrypt data.

Currently these two are stubs returning cleartext.

=cut

sub encrypt {
    my ($self, $data) = @_;
    # TODO
    return $data;
};

sub decrypt {
    my ($self, $data) = @_;
    # TODO
    return $data;
};

1;
