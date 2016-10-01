package MVC::Neaf::X::Session;

use strict;
use warnings;
our $VERSION = 0.09;

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

=head1 SINOPSYS

    use MVC::Neaf;
    use MVC::Neaf::X::Session;

    # somewhere in the beginning
    {
        package My::Session;

        sub save_session {
            my ($self, $id, $data) = @_;
            $self->{data}{ $id } = $data;
        };

        sub load_session {
            my ($self, $id) = @_;
            return $self->{data}{ $id };
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

=head1 METHODS

=cut

use Digest::SHA qw(sha1 sha224_base64);
use Time::HiRes qw(gettimeofday);
use Sys::Hostname qw(hostname);

use parent qw(MVC::Neaf::X);

=head2 new( %options )

The default constructor just happily closes over whatever is given to it.

=cut

=head2 session_id_regex()

This is supposed to be a constant regular expression
compatible with whatever get_session_id generates.

If none given, a sane default is supplied by Neaf itself.

=cut

sub session_id_regex {return};

=head2 get_session_id()

Generate a new, shiny, unique, unpredictable session id.

The default is using two rounds of sha1+sha224 with time, process id, hostname,
and random salt. Should be unique and reasonably hard to guess.

=cut

# Premature optimisation at its best.
# Should be more or less secure and unique though.
my $max = 2*1024*1024*1024;
my $uniq = 0;
my $old_rand = 0;
my $old_mix = '';
our $Seed = hostname() || '';

sub get_session_id {
    # argument not used

    $uniq = $max
        unless ($uniq-->0);
    my $rand = int ( rand() * $max );
    my ($time, $ms) = gettimeofday();

    # using old entropy means attacker will have to guess ALL previous sessions
    # Not need REAL secure hash or human readability
    $old_mix = sha1(pack "LLaaaaaLLLLL"
        , $old_rand, $uniq
        , "#", $Seed, "#", $old_mix, "#"
        , $$, $time, $ms, $uniq, $rand);

    # salt before second round of hashing
    # public data (session_id) should NOT be used for generation
    $old_rand = int (rand() * $max );
    return sha224_base64( pack "aL", $old_mix, $old_rand );
};

# finally, bootstrap the session generator at startap
get_session_id();

=head2 session_ttl()

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

This MUST be implemented in specific session driver class.

=cut

=head2 load_session( $id )

Return session data from the storage.

This MUST be implemented in specific session driver class.

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
