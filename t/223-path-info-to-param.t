#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf qw(:sugar);

my $capture;
get '/from/<foo=\d+>/to/<bar>' => sub {
    $capture = shift;
    +{}
}, -content => '';

my ($status, $head, $content) = neaf->run_test('/from/42/to/137');

is $status, 200, "Content found";

if ($capture) {
    is $capture->param(foo => '\d+'), 42, "first param";
    is $capture->param(bar => '\d+'), 137, "second param";
} else {
    ok 0, "Didn't route as expected";
};
undef $capture;

($status, $head, $content) = neaf->run_test('/from/foo/to/137');
is $status, 404, "Not allowed by path_info";

($status, $head, $content) = neaf->run_test('/from//to/137');
is $status, 404, "Not allowed by path_info";

($status, $head, $content) = neaf->run_test('/from/42/to/');
is $status, 404, "Not allowed by path_info";

done_testing;
