#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::Util::Container;

note "NORMAL CONTAINER";

my $c = MVC::Neaf::Util::Container->new;

$c->store( "first", path => "/foo", method => "GET" );
$c->store( "second", path => "/foo/bar", exclude => "/foo/bar/baz" );

is_deeply
      [ $c->fetch( method => 'GET', path => '/foo/bar' ) ]
    , ['first', 'second']
    , "ordering";

is_deeply
      [ $c->fetch( method => 'GET', path => '/foo/bar/baz' ) ]
    , ['first']
    , "exclusion";

is_deeply
      [ $c->fetch( method => 'GET', path => '/foo/bar/bazooka' ) ]
    , ['first', 'second']
    , "no exclusion";

is_deeply
      [ $c->fetch( method => 'POST', path => '/foo/bar' ) ]
    , ['second']
    , "Select by method";

note "EXCLUSIVE CONTAINER";

my $ex = MVC::Neaf::Util::Container->new( exclusive => 1 );

$ex->store( "first", path => [ "/foo", "/bar" ], method => [ "GET", "HEAD" ] );

eval {
    $ex->store( "nogo", path => [ '/baz', '/bar' ], method => [ "POST", "GET" ] );
};
like $@, qr#[Cc]onflict.*/bar\[GET\]#, "Conflict detected";
note $@;
is_deeply [ $ex->fetch( method => "POST", path => "/baz" ) ], [], "Atomic failure";

$ex->store( "maybe", path => [ "/foo", "/foo/bar", "/baz" ], tentative => 1 );

is_deeply
      [ $ex->fetch( method => 'GET', path => '/foo/bar/baz' ) ]
    , [ 'first', 'maybe' ]
    , "Tentative works";

$ex->store( "second", path => [ "/foo/bar" ] );

is_deeply
      [ $ex->fetch( method => 'GET', path => '/foo/bar/baz' ) ]
    , [ 'first', 'second' ]
    , "Tentative override works";

$ex->store( "over", path => '/foo', method => 'GET', override => 1 );

is_deeply
      [ $ex->fetch( method => 'GET', path => '/foo/bar/baz' ) ]
    , [ 'over', 'second' ]
    , "Override works";

done_testing;
