#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf;

note "TESTING error_template()";
my $n = MVC::Neaf->new;
$n->error_template( 404, { -template => \'NotFounded' } );
is_deeply ( $n->run->({})->[2], [ "NotFounded" ], "Template worked" );

note "TESTING on_error()";
my @log;
$n->on_error( sub { push @log, $_[1] } );
$n->route( '/' => sub { die "Fubar" } );
$n->run->({});
is (scalar @log, 1, "1 error issued");
like ($log[0], qr/^Fubar\s/s, "Error correct" );

note "TESTING set_default()";
$n = MVC::Neaf->new;
$n->set_default( -template => \'NotFounded2' );
$n->route( '/' => sub { +{} } );
is_deeply ( $n->run->({})->[2], [ "NotFounded2" ], "Template worked" );

note "TESTING duplicate route protection";
eval {
    $n->route( '/' => sub { +{ try => 2 } } );
};
like( $@, qr/^MVC::Neaf->route.*duplicat/, "Error starts with Neaf");
note $@;

done_testing;

