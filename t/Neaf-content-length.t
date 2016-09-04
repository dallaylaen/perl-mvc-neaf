#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf;

MVC::Neaf->route( "/" => sub {
    my $req = shift;
    return {
        -content => $req->path_info,
        -type => "text/plain",
    };
});

my $psgi = MVC::Neaf->run;

my $reply = $psgi->( { REQUEST_URI => "/%C2%A9", } );

note explain $reply;

my ($status, $head, $content) = @$reply;
$content = join "", @$content;

ok (!(@$head % 2), "headers are even");

my %head_hash = @$head;

is (length $content, $head_hash{'Content-Length'}
    , "Content-Length == real length");

done_testing;

