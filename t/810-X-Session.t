#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use URI::Escape;

use MVC::Neaf;
use MVC::Neaf::Request;

{
    package My::Session;
    use parent qw(MVC::Neaf::X::Session);

    our @call;

    sub load_session {
        my $self = shift;
        push @call, [ "load", @_ ];
        return { data => {} };
    };
    sub save_session {
        my $self = shift;
        push @call, [ "save", @_ ];
        return { id => shift };
    };
};

my $req = MVC::Neaf::Request->new( neaf_cookie_in => {cook => 137} );

$req->_set_session_handler([
    My::Session->new,
    'cook',
    '.+',
    '100',
]);

is_deeply ($req->session, {}, "Empty session ok");
$req->session->{foo} = 42;
$req->save_session;
$req->delete_session;
is_deeply (\@My::Session::call
    , [
        [ load => 137 ],
        [ save => 137, { foo => 42 } ],
        # and default delete worked & didn't die
    ]
    , "Sequence as expected");

note explain $req->format_cookies;
like( $req->format_cookies->[0], qr/cook=;/, "Deleted cookie appears" );

@My::Session::call = ();
MVC::Neaf->pre_route( sub {
    my $req = shift;

    $req->session->{foo}
        or $req->save_session( { foo => 42 } );
});
MVC::Neaf->set_session_handler( engine => My::Session->new );

my @ret = MVC::Neaf->run_test('/');

is ($ret[0], 404, "404 returned - no routes defined");

my $head = $ret[1];

my ($sess) = $head->header( 'Set-Cookie' ) =~ /session=(\S+);/;
ok ( $sess, "Set-Cookie appeared" );

is_deeply (\@My::Session::call
    , [
        # load never called - no cookie initially
        [ save => uri_unescape($sess), { foo => 42 } ],
    ]
    , "Sequence as expected");
done_testing;
