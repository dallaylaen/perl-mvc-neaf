#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use JSON;

use MVC::Neaf qw(:sugar);

neaf pre_route => sub { $_[0]->log_error( "mark 1\n" ); };
neaf pre_route => sub { $_[0]->log_error( ); };

neaf pre_logic => sub { $_[0]->log_error( "mark 2" ); };

get '/foo/bar' => sub {
    my $req = shift;
    $req->log_error( "mark 3" );
    $req->log_error;

    die "Foobared";
};

# Cannot use warnings_like - we don't know what to expect before running
#     the code
{
    my @warn;
    local $SIG{__WARN__} = sub { push @warn, shift };

    my $content = neaf->run_test( '/foo/bar' );
    my $ref = eval {
        decode_json( $content );
    };
    diag "Decode failed: ".$@ || "unknown reason"
        unless $ref;

    is ref $ref, 'HASH', "A hash returned";
    is $ref->{error}, 500, "Error 500 reported";
    ok $ref->{req_id}, "request_id present";

    my $id = $ref->{req_id};
    note "req_id=$id";

    my $file = __FILE__;

    is scalar @warn, 6, "6 warnings issued";
    like $warn[0], qr/req.*$id.*pre_route.*mark 1\n$/, "pre_route, msg";
    like $warn[1], qr/req.*$id.*pre_route.*$file line \d+\.?\n$/
        , "pre_route, unknown msg = attributed to caller";
    like $warn[2], qr/req.*$id.*\/foo\/bar.*mark 2\n$/
        , "pre_logic: path defined";
    like $warn[3], qr/req.*$id.*\/foo\/bar.*mark 3\n$/
        , "controller itself";
    like $warn[4], qr/req.*$id.*\/foo\/bar.*$file line \d+\.?\n$/
        , "controller itself, attributed to caller";
    like $warn[5], qr/req.*$id.*\/foo\/bar.*Foobared.*$file line \d+\.?\n$/
        , "Error message itself";

    note "WARN: $_" for @warn;
}

done_testing;
