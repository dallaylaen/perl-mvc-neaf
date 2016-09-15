#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Basename qw(basename);

use MVC::Neaf;

MVC::Neaf->static( t => $Bin, buffer => 1024*1024 );

my $self = basename( __FILE__ );

my $data = MVC::Neaf->run->({ REQUEST_URI => "/t/$self" });
my ($status, $head_raw, $content) = @$data;
my %head = @$head_raw;
$content = join "", @$content;

is ($status, 200, "Found self");
is ($head{'Content-Type'}, 'text/plain; charset=utf-8', "Served as text");
is ($head{'Content-Length'}, length $content, "Length");

done_testing;
