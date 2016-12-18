#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf;

my @call;

MVC::Neaf->route( rest => sub { push @call, "foo"; +{} }, method => 'GET' );
MVC::Neaf->route( rest => sub { push @call, "bar"; +{} }, method => 'POST' );

eval {
    MVC::Neaf->route( rest => sub {}, method => 'GET' );
};
like ($@, qr/MVC::Neaf.*duplicate/, "Dupe handler = no go");
note $@;

my $app = MVC::Neaf->run;

is ($app->( { REQUEST_METHOD => 'GET', REQUEST_URI => '/rest' } )->[0], 200
    , "Get ok" );
is ($app->( { REQUEST_METHOD => 'POST', REQUEST_URI => '/rest' } )->[0], 200
    , "Post ok" );
is ($app->( { REQUEST_METHOD => 'HEAD', REQUEST_URI => '/rest' } )->[0], 405
    , "Head not ok (HEAD may become truncated GET in the future)" );

my @put405 = MVC::Neaf->run_test(
    { REQUEST_METHOD => 'PUT', REQUEST_URI => '/rest' } );

is( $put405[0], 405, "Put gets 405 error");
like( $put405[1]->header("Allow"), qr/^(GET, POST|POST, GET)$/
    , "Allow header present" );

is_deeply( \@call, [ "foo", "bar" ], "Call sequence as expected" );

done_testing;
