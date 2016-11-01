#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::Request::PSGI;

my $req = MVC::Neaf::Request::PSGI->new( env => {
        REQUEST_METHOD => 'GET',
        QUERY_STRING   => 'foo=42&foo=137',
    } );

is ( $req->param( foo => '\d+' ), 137, "Second value if single param" );
is_deeply ( [$req->multi_param( foo => '\d+' )], [ 42, 137 ]
    , "Multi param happy case" );
is_deeply ( [$req->multi_param( foo => '\d\d' )], []
    , "Mismatch = no go" );


done_testing;
