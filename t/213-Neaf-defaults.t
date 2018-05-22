#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use MVC::Neaf::Util qw(JSON encode_json decode_json);

use MVC::Neaf;

neaf->route( '/foo/bar' => sub { +{} }
    , default => { lang => 'Perl' }
    , -view => 'JS'
    , -type => 'x-text/jason'
);

neaf->set_path_defaults( '/foo' => { answer => 42 } );
neaf->set_path_defaults( '/foo' => { fine => 137 } );
neaf->set_path_defaults( '/f' => { rubbish => 314 } );

my ($status, $head, $result)
    = neaf->run_test( { REQUEST_URI => '/foo/bar' } );

is $status, 200, "Request ok";
is_deeply( decode_json($result)
    , { lang => 'Perl', answer => 42, fine => 137 }
    , "Returned value as exp" );

is (scalar $head->header('content_type')
    , 'x-text/jason; charset=utf-8'
    , 'Custom -type propagates');

done_testing;
