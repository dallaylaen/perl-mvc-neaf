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
is ($app->( { REQUEST_METHOD => 'PUT', REQUEST_URI => '/rest' } )->[0], 405
    , "Put not ok" );
is_deeply( \@call, [ "foo", "bar" ], "Call sequence as expected" );

done_testing;
