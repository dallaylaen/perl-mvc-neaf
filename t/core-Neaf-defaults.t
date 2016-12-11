#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use JSON;

use MVC::Neaf;

MVC::Neaf->route( '/foo/bar' => sub { +{} }
    , default => { lang => 'Perl' }
    , view => 'JS',
);

my (undef, undef, $result) = MVC::Neaf->run_test( { REQUEST_URI => '/foo/bar' } );

is_deeply( decode_json($result), { lang => 'Perl' }, "Returned value as exp" );

done_testing;
