#!/usr/bin/env perl

use strict;
use warnings;

# always use latest and gratest libraries, not the system ones
use FindBin qw($Bin);
use File::Basename qw(dirname);
use lib dirname($Bin)."/lib";
use MVC::Neaf;

my $tpl = <<"TT";
<html>
<head>
    <title>Continued request</title>
</head>
<body>
<form method="GET">
    <input name="start" value="[% start %]">
    <input name="step"  value="[% step %]">
    <input name="end"   value="[% end %]">
    <input type="submit" value="Generate">
</form>
<hr>
TT

MVC::Neaf->route( dl => sub {
    my $req = shift;

    # TODO Form validation needs to be implemented for such cases
    my $start = $req->param( start => '\d+(\.\d+)?', 1);
    my $end   = $req->param( end   => '\d+(\.\d+)?', 0);
    my $step  = $req->param( step  => '\d+(\.\d+)?', 1);

    my $continue = ($start <= $end && $step > 0) ? sub {
        my $req = shift;

        while ($start <= $end) {
            $req->write("$start<br>");
            $start += $step;
        }

            $req->close;
    } : undef;

    return {
        start => $start,
        end   => $end,
        step  => $step,
        -template => \$tpl,
        -continue => $continue,
    };
});

MVC::Neaf->run;
