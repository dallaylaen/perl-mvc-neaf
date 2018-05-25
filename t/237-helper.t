#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use MVC::Neaf::Util qw(decode_json);

use MVC::Neaf;

my $handler = sub {
    my $req = shift;

    +{ global => $req->my_global, local => $req->my_local, path => $req->path };
};

neaf->set_helper( my_global => sub { "global:".ref $_[0] } );
neaf->set_helper( my_local  => sub { "not to be seen" }, exclude => '/none' );
neaf->set_helper( my_local  => sub { "onlyfoo" }, path => '/foo' );
neaf->set_helper( my_local  => sub { "onlybar" }, path => '/foo/bar' );

get '/foo' => $handler;
get '/foo/bar/baz' => $handler;
get '/none' => $handler;

my $err_trace;
neaf->on_error( sub { $err_trace = shift } );
neaf pre_route => sub { undef $err_trace };

my ($status, $head, $content);

($status, $head, $content) = neaf->run_test( '/foo' );
is $status, 200, "Request works";
is_deeply decode_json($content), {
    global => 'global:MVC::Neaf::Request::PSGI',
    local  => 'onlyfoo',
    path   => '/foo',
}, "Content as expected";

($status, $head, $content) = neaf->run_test( '/foo/bar/baz' );
is $status, 200, "Request works";
is_deeply decode_json($content), {
    global => 'global:MVC::Neaf::Request::PSGI',
    local  => 'onlybar',
    path   => '/foo/bar/baz',
}, "Content as expected";

($status, $head, $content) = neaf->run_test( '/none' );
is $status, 500, "Request doesn't work";
note "error: ", $err_trace;
note $content;

done_testing;
