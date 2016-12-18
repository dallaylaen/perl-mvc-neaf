#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

# TODO Kill this test after 0.15 is released and old load/save session killed

use MVC::Neaf::Request;

{
    package My::Old::Session;
    use parent qw(MVC::Neaf::X::Session);

    sub save_session {
        return 1;
    };
    sub load_session {
        return { user_id => 1 };
    };
};

my $sess = My::Old::Session->new;

my $req = MVC::Neaf::Request->new(
    session_engine => $sess,
    session_regex  => $sess->session_id_regex,
    session_cookie => 'session',
    header_in      => HTTP::Headers->new( cookie => 'session=foo42;' ),
);

my @warn;
$SIG{__WARN__} = sub {
    my $w = shift;
    $w =~ /DEPRECATED/ or Carp::confess $w;
    push @warn, $w;
};

is_deeply( $req->session, { user_id => 1 }, "OLD Load session works" );
like ($warn[0], qr/DEPRECATED.*load_session/, "Warning issued" );
note $warn[0];
@warn = ();

$req->save_session( { foo => 42 } );
is_deeply( $req->format_cookies, [ 'session=foo42; Path=/' ], "Cookie out" );
like ($warn[0], qr/DEPRECATED.*load_session/, "Warning issued" );
note $warn[0];
@warn = ();

done_testing;
