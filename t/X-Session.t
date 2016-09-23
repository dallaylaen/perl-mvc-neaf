#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::Request;

{
    package My::Session;
    use parent qw(MVC::Neaf::X::Session);

    our @call;

    sub load_session {
        my $self = shift;
        push @call, [ "load", @_ ];
        return {};
    };
    sub save_session {
        my $self = shift;
        push @call, [ "save", @_ ];
    };
};

my $req = MVC::Neaf::Request->new(
    session_engine => My::Session->new,
    session_cookie => 'cook',
    session_regex  => '.+',
    neaf_cookie_in => {cook => 137},
);

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

done_testing;
