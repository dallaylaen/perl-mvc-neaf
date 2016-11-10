#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::Request::PSGI;
use MVC::Neaf::X::Session::Cookie;

my $engine = MVC::Neaf::X::Session::Cookie->new(
);

my $req = MVC::Neaf::Request::PSGI->new(
    session_engine => $engine,
    session_cookie => 'session',
    session_regex  => $engine->session_id_regex,
);

$req->session->{foo} = 42;
$req->session->{bar} = 137;
$req->save_session;
my $cook = join " ", map { /^(\S+?=\S*;)/ } @{ $req->format_cookies };

note explain $req->session;

note explain $cook;

my $req2 = MVC::Neaf::Request::PSGI->new(
    session_engine => $engine,
    session_cookie => 'session',
    session_regex  => $engine->session_id_regex,
    env => { HTTP_COOKIE => $cook },
);

is_deeply( $req2->session, $req->session, "Session round trip" );

note explain $req2->session;

done_testing;
