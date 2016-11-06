#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use MVC::Neaf::X::Session::File;

eval {
    MVC::Neaf::X::Session::File->new;
};
like ($@, qr/dir/, "no dir = no go");

my $temp = tempdir( CLEANUP => 1 );

my $sess = MVC::Neaf::X::Session::File->new( dir => $temp );

$sess->save_session( 'foo/../bar' => { bar => 42 } );
is_deeply( $sess->load_session( "foo" ), undef, "No such session ok" );
my $data = $sess->load_session( "foo/../bar" );

is_deeply( $data, { bar => 42 }, "Session data round trip" );

my $sess_un = MVC::Neaf::X::Session::File->new( dir => $temp
    , session_ttl => -100 );

$sess_un->save_session( foo => { bar => 42 } );
is_deeply( $sess_un->load_session( "foo" ), undef, "ttl < 0 - expired" );

done_testing;
