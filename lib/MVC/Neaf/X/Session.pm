package MVC::Neaf::X::Session;

use strict;
use warnings;
our $VERSION = 0.0601;

=head1 NAME

MVC::Neaf::X::Session - Session backend base class for Not Even A Framework

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
    MVC::Neaf->set_session_handler( MVC::Neaf::X::Session->new(
        on_load_session => sub { ... },
        on_save_session => sub { ... },
    ));

    # somewhere in the controller
    sub {
        my $req = shift;

        $req->session; # {} 1st time, { user => ... } second time
        $req->session->{user} = $user;
        $req->save_session;
    };

=head1 SYNOPSIS AGAIN

The following is a working in-memory session storage -
provided that your app runs in one process and has few users.

    package My::Session;

    use strict;
    use warnings;
    use parent qw(MVC::Neaf::X::Session);

    sub on_load_session {
        my ($self, $key) = @_;
        return $self->{storage}{$key} || {};
    };

    sub on_save_session {
        my ($self, $key, $data) = @_;
        $self->{storage}{$key} = $data;
    };

    1;

=head1 METHODS

=cut

use Digest::MD5 qw(md5_base64);

use parent qw(MVC::Neaf::X);

my $seed = 'xxx';
eval {
    require Sys::Hostname;
    $seed = Sys::Hostname::hostname();
    # Ignore errors
};

=head2 new( %options )

%options may include:

=over

=item * session_cookie - which cookie to use for session. Default: "session"

=item * seed - a machine-dependent part of session identifier.
Defaults to hostname, or 'xxx' if cannot determine.

=item * session_ttl - time to live for session data & cookie.

=item * on_load_session - callback to load session data.
This is required unless you use subclass and define do_load_session() method.

=item * on_save_session - callback to load session data.
This is required unless you use subclass and define do_save_session() method.

=item * on_delete_session - callback to delete session data.
If none given, just omit this step.

B<NOTE> it is usually a good idea to cleanup session data from time to time
since some users may go away without logging out
(cleaned cookies, laptop eaten by crocodiles etc).

=back

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{session_cookie} ||= 'session';
    $self->{seed} ||= $seed;
    return $self;
};

=head2 load_session( $req )

Loads session based on request object.

This is usually called by $req->session.
No need to call manually.

=cut

sub load_session {
    my ($self, $req) = @_;

    my $cook = $self->{session_cookie};
    my $data;

    if (my $key = $req->get_cookie( $cook => qr/[\x20-\x7F]+/ )) {
        $data = $self->backend_call("load_session", $key);
    };

    $data ||= $self->backend_call("create_session");
    return $data;
};

=head2 save_session( $req )

Save request object's session data via the engine.

This is usually called by $req->save_session.
No need to call manually.

=cut

sub save_session {
    my ($self, $req) = @_;

    my $cook = $self->{session_cookie};
    my $key = $req->get_cookie( $cook => qr/[\x20-\x7F]+/ );

    if (!$key) {
        # no key, generate new one
        $key = $self->backend_call("get_session_id");
        $req->set_cookie( $cook => $key, ttl => $self->{session_ttl} );
    };

    $self->backend_call("save_session", $key, $req->session);
};

=head2 delete_session( $req )

Delete session cookie (may NOT be honored by the user agent)
and remove session from storage.

=cut

sub delete_session {
    my ($self, $req) = @_;

    my $cook = $self->{session_cookie};
    my $key = $req->get_cookie( $cook => qr/[\x20-\x7F]+/ );
    return unless $key; # Don't know what to delete

    $req->set_cookie( $cook => '', ttl => -1000 );
    return $self->backend_call("delete_session", $key);
};

=head1 ENGINE METHODS

=head2 do_create_session

What to do when new session is created. Default is to return an empty hashref.

=cut

# Override in your package or via callback
sub do_create_session {
    return {};
};

=head2 do_load_session

What to do when session needs to be loaded.
Default: none.

=head2 do_save_session

What to do when session needs to be saved.
Default: none.

=head2 do_delete_session

What to do when session needs to be deleted.
Default: do nothing and hope it goes away.

=cut

sub do_delete_session {
    # do nothing and hope the storage won't fill up
    return;
};

=head2 do_get_session_id

How to calculate session ids.

Default is md5_base64( random, counter, '#', hostname, '#', pid, time, counter,
random ).
counter is decreased with every call, and initialized with a random value
when it reaches zero.

=cut

# Premature optimisation at its best.
# Should be more or less secure and unique though.
my $max = 2*1024*1024*1024;
my $uniq;
my $time;
sub do_get_session_id {
    my $self = shift;

    unless ($uniq-->0) {
        $uniq = int( rand() * $max );
        $time = time;
    };
    my $rand = int ( rand() * $max );

    return md5_base64(pack "LLaaaLLLL"
        , $rand, $uniq, "#", $self->{seed}, "#", $$, $time, $uniq, $rand);
};

1;
