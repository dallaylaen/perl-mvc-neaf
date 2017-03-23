package MVC::Neaf::X::Session::Cookie;

use strict;
use warnings;
our $VERSION = 0.1502;

=head1 NAME

MVC::Neaf::X::Session::Cookie - Stateless cookie-based session for Neaf

=head1 DESCRIPTION

Use this module as a session handler in a Neaf app.

=head1 METHODS

=cut

use MIME::Base64 qw( encode_base64 decode_base64 );
use Digest::SHA;

use parent qw( MVC::Neaf::X::Session::Base );

=head2 new( %options )

%options may include:

=over

=item * key (required) - a security key to prevent tampering with
the cookie data.
This should be the same throughout the application.

=item * hmac_function - HMAC to be used, default is hmac_sha224_base64

=back

=cut

sub new {
    my ($class, %opt) = @_;

    $opt{key} or $class->my_croak( "key option is required" );

    $opt{hmac_function} ||= \&Digest::SHA::hmac_sha224_base64;

    return $class->SUPER::new( %opt );
};

=head2 store( $id, $data )

Create a cookie from $data hash. Given $id is ignored.

=cut

sub store {
    my ($self, $id, $data) = @_;

    # TODO Make universal HMAC for ALL cookies
    my $str = encode_base64($data);
    $str =~ s/\s//gs;
    my $sum = $self->{hmac_function}->( $str, $self->{key} );

    return { id => "$str~$sum" };
};

=head2 fetch

Restore session data from cookie.

=cut

sub fetch {
    my ($self, $id) = @_;

    return unless $id =~ m#^([A-Za-z0-9=/+]+)~([A-Za-z0-9=/+]+)$#;
    my ($str, $key) = ($1, $2);

    return unless $self->{hmac_function}->( $str, $self->{key} ) eq $key;

    return { data => decode_base64($str) };
};

=head2 get_session_id

Replaced by a stub - we'll generate ID from data anyway.

=cut

sub get_session_id { return 'Cookie Session Need No Id' };

1;
