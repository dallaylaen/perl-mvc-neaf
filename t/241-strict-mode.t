#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use MVC::Neaf::Util qw(decode_json);

use MVC::Neaf;

get '/strict' => sub {
    my $req = shift;
    +{
        id   => $req->param( id => '\d+' ),
        sess => $req->get_cookie( sess => '\w+' ),
        name => $req->postfix,
    };
}, path_info_regex => '...', strict => 1;

my ($status, undef, $content) = neaf->run_test(
    '/strict/foo?id=42',
    cookie => { sess => 137 }
);
is $status, 200, "Happy case ok";
is_deeply decode_json( $content )
    , { name => 'foo', id => 42, sess => 137 }
    , "Happy case param round-trip";

($status) = neaf->run_test(
    '/strict/foobar?id=42',
    cookie => { sess => 137 },
);
is $status, 404, "postfix regex failed (TODO 422 as well)";

($status) = neaf->run_test(
    '/strict/foo?id=x42',
    cookie => { sess => 137 },
);
is $status, 422, "param regex failed";

($status) = neaf->run_test(
    '/strict/foobar?id=42',
    cookie => { sess => 'words with spaces' },
);
is $status, 404, "cookie regex failed";

done_testing;

