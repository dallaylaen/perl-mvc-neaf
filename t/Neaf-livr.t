#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use JSON::XS;

use MVC::Neaf;

if ( !eval {require Validator::LIVR;} ) {
    plan skip_all => "No LIVR found, skipping";
};

MVC::Neaf->route( "/" => sub {
    my $req = shift;

#    note " ########## ", explain $req;

    return {
        form => $req->form,
        fail => $req->form_errors,
        raw  => $req->form_raw,
    };
}, form => {
    foo => 'required',
    bar => 'integer',
    baz => { like => '^%\w+$' },
}, view => 'JS' );

my $app = MVC::Neaf->run;

my $reply;

$reply = $app->({
    REQUEST_METHOD => 'GET',
    QUERY_STRING => "bar=42",
})->[2][0];
is_deeply (decode_json($reply)
    , {form => undef, fail => {foo=>"REQUIRED"}, raw =>{ bar => 42 } }
    , "Form processed - 1")
    or diag $reply;

$reply = $app->({
    REQUEST_METHOD => 'GET',
    QUERY_STRING => "foo=1&bar=xxx",
})->[2][0];
is_deeply (decode_json($reply)
    , {form => undef, fail => { bar=>"NOT_INTEGER"}, raw => { foo => 1, bar => "xxx" } }
    , "Form processed - 2")
    or diag $reply;

$reply = $app->({
    REQUEST_METHOD => 'GET',
    QUERY_STRING => "foo=1",
})->[2][0];
is_deeply (decode_json($reply)
    , {form => {foo => 1}, fail => undef, raw => { foo=> 1} }
    , "Form processed - 3")
    or diag $reply;

done_testing;
