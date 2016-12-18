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

MVC::Neaf->set_path_defaults( '/foo' => { answer => 42 } );
MVC::Neaf->set_path_defaults( '/foo' => { fine => 137 } );
MVC::Neaf->set_path_defaults( '/f' => { rubbish => 314 } );

my (undef, undef, $result) = MVC::Neaf->run_test( { REQUEST_URI => '/foo/bar' } );

is_deeply( decode_json($result)
    , { lang => 'Perl', answer => 42, fine => 137 }
    , "Returned value as exp" );

done_testing;
