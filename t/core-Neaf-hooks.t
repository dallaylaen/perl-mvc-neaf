#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf;

# test route
MVC::Neaf->route( '/foo/bar/baz' => sub { +{} }, view => 'JS' );

# hooks which we're testing
my $trace = '';
MVC::Neaf->add_hook( pre_logic => sub { $trace .= 1 } );
MVC::Neaf->add_hook( pre_logic => sub { $trace .= 2 }, path => '/foo' );
MVC::Neaf->add_hook( pre_logic => sub { $trace .= 3 }, path => '/foo' );
MVC::Neaf->add_hook( pre_logic => sub { $trace .= 4 }, path => '/foo', method => 'POST' );

# run it!
my ($status, $head, $content) = MVC::Neaf->run_test(
    { REQUEST_URI => '/foo/bar/baz' } );

is ($status, 200, "http ok");
is ($content, '{}', "content ok");

is ($trace, '123', "Hooks come in order" );

$trace = '';
MVC::Neaf->run_test( { REQUEST_URI => '/foo/bar/baz' } );
is ($trace, '123', "Hooks not reinstalled" );

done_testing;
