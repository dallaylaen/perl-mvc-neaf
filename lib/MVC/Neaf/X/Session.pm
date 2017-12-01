package MVC::Neaf::X::Session;

use strict;
use warnings;
our $VERSION = 0.2001;

=head1 NAME

MVC::Neaf::X::Session - Session engine base class for Not Even A Framework

=head1 DESCRIPTION

A framework, even a toy one, is incomplete until it can handle user sessions.

This class offers managing sessions via a cookie ("session" by default)
plus a user-defined backend storage mechanism.

Whatever is stored in the session, stays in the session - until it's deleted.

Within the application, session is available through Request methods
session(), save_session(), and delete_session().
During the setup phase, MVC::Neaf->set_session_handler( $engine )
must be called in order to make use of those.

This class is base class for such $engine.

To actually manage sessions, it MUST be subclassed with methods
save_session() and load_session() implemented.
For a working implementation, please see L<MVC::Neaf::X::Session::File>.

This module's interface is still under development and details MAY
change in the future.

=head1 SINOPSYS

    use MVC::Neaf;
    use MVC::Neaf::X::Session;

    # somewhere in the beginning
    {
        package My::Session;

        sub save_session {
            my ($self, $id, $data) = @_;
            $self->{data}{ $id } = $data;
            return { id => $id };
        };

        sub load_session {
            my ($self, $id) = @_;
            return { data => $self->{data}{ $id } };
        };
    };
    MVC::Neaf->set_session_handler( My::Session->new );

    # somewhere in the controller
    sub {
        my $req = shift;

        $req->session; # {} 1st time, { user => ... } later on
        $req->session->{user} = $user;
        $req->save_session;
    };

This of course is only going to work as a standalone application server
(plackup, twiggy...), but not CGI or Apache/mod_perl.

=head1 METHODS

=cut

use Digest::MD5;
use Time::HiRes qw(gettimeofday);
use Sys::Hostname qw(hostname);
use MIME::Base64 qw(encode_base64);

use parent qw(MVC::Neaf::X);

=head2 new( %options )

%options may include

=over

=item * session_ttl, expire - the lifetime of session.
Default is 24 hours.

=back

=cut

sub new {
    my ($class, %opt) = @_;

    $opt{session_ttl} ||= delete $opt{expire} || 24*60*60;

    $class->SUPER::new( %opt );
};

=head2 session_id_regex()

This is supposed to be a constant regular expression
compatible with whatever get_session_id generates.

If none given, a sane default is supplied.

=cut

sub session_id_regex {
    return qr([A-Za-z_\d\.\/\?\-\@+=~]+);
};

=head2 get_session_id( [$user_salt] )

Generate a new, shiny, unique, unpredictable session id.
Id is base64-encoded.

The default is using two rounds of md5 with time, process id, hostname,
and random salt. Should be unique and reasonably hard to guess.

If argument is given, it's also added to the mix.

Set $MVC::Neaf::X::Session::Hash to other function (e.g. Digest::SHA::sha224)
if md5 is not secure enough.

Set $MVC::Neaf::X::Session::Host to something unique if you know better.
Default is hostname.

Set $MVC::Neaf::X::Session::Truncate to the desired length
(e.g. if length constraint in database).
Default (0) means return however many chars are generated by hash+base64.

=cut

# Premature optimisation at its best.
# Should be more or less secure and unique though.
my $max = 2*1024*1024*1024;
my $count = 0;
my $old_rand = 0;
my $old_mix = '';
our $Host = hostname() || '';
our $Hash = \&Digest::MD5::md5;
our $Truncate;

sub get_session_id {
    my ($self, $salt) = @_;

    $count = $max
        unless $count--;
    my $rand = int ( rand() * $max );
    my ($time, $ms) = gettimeofday();
    $salt = '' unless defined $salt;

    # using old entropy means attacker will have to guess ALL previous sessions
    $old_mix = $Hash->(pack "La*a*a*a*LLLLa*L"
        , $rand, $old_mix, "#"
        , $Host, '#', $$, $time, $ms, $count
        , $salt, $old_rand);

    # salt before second round of hashing
    # public data (session_id) should NOT be used for generation
    $old_rand = int (rand() * $max );
    my $ret = encode_base64( $Hash->( pack "a*L", $old_mix, $old_rand ) );
    $ret =~ s/[\s=]+//gs;
    $ret = substr( $ret, 0, $Truncate )
        if $Truncate and $Truncate < length $ret;
    return $ret;
};

# finally, bootstrap the session generator at startap
get_session_id();

=head2 session_ttl()

Return session ttl.

=cut

sub session_ttl {
    my $self = shift;
    return $self->{session_ttl};
};

=head2 create_session()

Create a new session. The default is to return an empty hash.

=cut

sub create_session { return {} };

=head2 save_session( $id, $data )

Save session data in the storage.

This method MUST be implemented in specific session driver class.

It MUST return a hashref with the following fields:

=over

=item * id - the id of session (either supplied, or a new one).
If this value is absent or false, saving is considered unsuccessful.

=item * expire - the expiration time of the session as Unix time.
This is optional.

=back

=cut

=head2 load_session( $id )

Return session data from the storage.

This MUST be implemented in specific session driver class.

It MUST return either false, or a hashref with the following fields:

=over

=item * data - the session data that was passed to corresponding save_session()
call. If absent or false, loading is considered unsuccessful.

=item * id - if present, this means that session has to be refreshed.
The session cookie will be sent again to the user.

=item * expire - if id present, this would set new session expiration date.

=back

=cut

=head2 delete_session( $id )

Remove session from storage.

The default is do nothing and wait for session data to rot by itself.

B<NOTE> It is usually a good idea to cleanup session storage
from time to time since some users may go away without logging out
(cleaned cookies, laptop eaten by crocodiles etc).

=cut

sub delete_session { return };

1;
