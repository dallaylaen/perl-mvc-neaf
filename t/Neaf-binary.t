#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf;
MVC::Neaf->route( "/" => sub {
    return { -content => chr(255) };
} );
my $data = MVC::Neaf->run->( {} );
my ($status, $head, $content) = @$data;
my %head_hash = @$head;
$content = join "", @$content;

is ($head_hash{'Content-Length'}, length $content, "binary length");
is ($head_hash{'Content-Type'},   'application/octet-stream', "binary type");

done_testing;
