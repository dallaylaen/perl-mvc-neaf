#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::CLI;

use MVC::Neaf;
MVC::Neaf->route( foo => sub { +{}} );
MVC::Neaf->route( bar => sub { +{}} );

my $data;
{
    local *STDOUT;
    open (STDOUT, ">", \$data) or die "Failed to redirect STDOUT";
    local @ARGV = qw(--list);

    MVC::Neaf->run;
};
is ($data, "/bar\n/foo\n", "--list works");

{
    local *STDOUT;
    open (STDOUT, ">", \$data) or die "Failed to redirect STDOUT";
    local @ARGV = qw(--view JS /foo);

    MVC::Neaf->run;
};
like ($data, qr/\n\n{}$/s, "force view worked");

done_testing;
