#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf qw(:sugar);

get  foo => sub {+{}}, view => 'JS';
post bar => sub {+{}}, view => 'JS';

neaf error => 404 => { -content => 'Second Foundation' };

my @re = neaf->run_test( '/foo?x=42' );
is ($re[0], 200, "request ok");
is ($re[2], '{}', "content ok");

@re = neaf->run_test( '/bar?x=42' );
is ($re[0], 405, "wrong method" );

@re = neaf->run_test( '/baz?x=42' );
is ($re[0], 404, "not found" );
is ($re[2], 'Second Foundation', "2nd foundation is not found" );

done_testing;
