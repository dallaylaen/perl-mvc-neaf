#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Warn;
use JSON::MaybeXS;

use MVC::Neaf qw(:sugar);

my $file = __FILE__;
get '/garbled' => sub {"Hello world!"}; my $line = __LINE__;


my $content;
warnings_like {
    $content = neaf->run_test('/garbled');
} [qr/[Rr]eturn.*SCALAR.*\b$file\b.*\b$line\.?\n?$/], "Warning correct";

my $ref = eval {
    decode_json( $content );
};
ok $ref, "Json returned"
    or diag "FAIL: $@";

is $ref->{error}, 500, "Error 500";

done_testing;