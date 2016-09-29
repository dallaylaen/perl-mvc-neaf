#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf;
# MVC::Neaf::CLI monkey-patches MVC::Neaf which in turn affects other
# tests when run under cover -t.
# So localize the change...

{
local *MVC::Neaf::run = MVC::Neaf->can("run");

use MVC::Neaf::CLI;

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

};
# end localize

done_testing;
