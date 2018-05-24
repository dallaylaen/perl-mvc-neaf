#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::Util::Container;

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

done_testing;
