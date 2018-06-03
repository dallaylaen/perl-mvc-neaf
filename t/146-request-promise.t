#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::Request;

my $req = MVC::Neaf::Request->new( method => 'GET', path => '/foo' );

ok !$req->{is_async}, "Not async yet";

subtest "Future first, timeout" => sub {
    my @trace;
    my $future = $req->async;
    ok $req->is_async, "Async mode on";
    is $future->method, "GET", "Proxy method works";
    undef $future; # TODO test leak

    $req->_maybe_continue( sub { push @trace, [@_] } );

    is scalar @trace, 1, "1 call logged";
    is $trace[0][0], $req, "Continue fired";
    is $trace[0][1], "510 Timeout", "Undef future = timeout recorded";
    ok !$req->is_async, "No more async mode";
};

subtest "Code first, return" => sub {
    my @trace;
    my $future = $req->async;
    ok $req->is_async, "Async mode on";

    $req->_maybe_continue( sub { push @trace, [@_] } );

    is scalar @trace, 0, "Nothing executed yet";
    ok $req->is_async, "Async mode still on";

    $future->return( { foo => 42 } );

    ok !$req->is_async, "Async no more";
    is scalar @trace, 1, "1 call recorded";
    is $trace[0][0], $req, "Called correctly";
    is $trace[0][1], undef, "No error => second arg undef";
    is_deeply $req->reply, { foo => 42 }, "Reply data round-trip"
};

done_testing;
