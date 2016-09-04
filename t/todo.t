#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Basename qw(dirname);

# This test is mainly here for making developer
# feel bad about untested modules.

my $path = dirname($Bin)."/lib";
my @files = `find $path -type f`;

my @warn;
foreach (@files) {
    local $SIG{__WARN__} = sub {
        my $w = shift;

        $w =~ /^Subroutine.*redefined/
            or $w =~ /Some Apache2 modules failed to load/
            or push @warn, $w;
        return; # somehow this supresses warnings under make test
    };

    chomp;
    ok ( eval{ require $_ }, "$_ loaded" )
        or diag "Error in $_: $@";
};

foreach (@warn) {
    diag "WARN: $_";
};

is( scalar @warn, 0, "No warnings during load (except redefined)" );

done_testing;
