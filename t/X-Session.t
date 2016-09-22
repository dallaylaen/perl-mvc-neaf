#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::X::Session;
use MVC::Neaf::Request;

eval {
    my $sess0 = MVC::Neaf::X::Session->new( on_load_session => 42 );
};
like ( $@, qr/^MVC::Neaf::X::Session->new.*on_load_session/, "Error as exp" );
note $@;

my @call;
my $sess = MVC::Neaf::X::Session->new(
    on_load_session => sub {
        my $self = shift;
        push @call, [ "load", @_ ];
        return {};
    },
    on_save_session => sub {
        my $self = shift;
        push @call, [ "save", @_ ];
    },
);

my $req = MVC::Neaf::Request->new( session_handler => $sess,
    neaf_cookie_in => {session => 137} );

is_deeply ($req->session, {}, "Empty session ok");
$req->session->{foo} = 42;
$req->save_session;
$req->delete_session;
is_deeply (\@call
    , [
        [ load => 137 ],
        [ save => 137, { foo => 42 } ],
        # and default delete worked & didn't die
    ]
    , "Sequence as expected");

note explain $req->format_cookies;
like( $req->format_cookies->[0], qr/session=;/, "Deleted cookie appears" );

done_testing;
