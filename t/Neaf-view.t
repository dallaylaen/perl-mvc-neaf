#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::View::TT;
use MVC::Neaf::View::JS;

my $tt = MVC::Neaf::View::TT->new;

is_deeply ( [$tt->render({})], [ '', 'text/plain' ], "Plain return if no tpl");
is_deeply ( [$tt->render( { -template => \"[% foo %]", foo => 42 } ) ]
    , [ 42, 'text/html' ], "TT as expected" );

my $js = MVC::Neaf::View::JS->new;
is_deeply ([ $js->render( { -template => "foo", code => sub { }, x => "Y" } ) ]
    , ['{"x":"Y"}', "application/json; charset=utf-8" ], "JSON render is safe");
is_deeply ([ $js->render( { -callback => "foo.bar" } ) ],
    , ['foo.bar({});', "application/javascript; charset=utf-8" ], "jsonp callback worked" );
is_deeply ([ $js->render( { -callback => 'alert("pwned!");foo.bar' } ) ],
    , ['{}', "application/json; charset=utf-8" ]
    , "jsonp exploit didn't work" );



done_testing;
