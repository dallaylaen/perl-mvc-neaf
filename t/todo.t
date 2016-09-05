#!/usr/bin/env perl

# This script tests nothing (except the fact that modules load w/o warnings).
# However, it tries to load them all.
# This means that untested modules would also be included into
# code coverage summary, lowering total coverage to its actual value.

# I.e. having a well-covered module and a totally uncovered one will result
# in 50% coverage which is probably closer to truth.

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Basename qw(dirname);

# Try to load EVERY module in t/../lib
my $path = dirname($Bin)."/lib";
my @files;

if (eval { require File::Find::Rule }) {
    @files = File::Find::Rule->file()->name('*.pm')->in($path);
} else {
    # fallback to shelling out
    @files = `find $path -type f -name \*.pm`;
};

# Save warnings for later
my @warn;

foreach my $file (@files) {
    chomp $file;

    # This sub suppresses warnings but saves them for later display
    local $SIG{__WARN__} = sub {
        my $w = $_[0];

        $w =~ /^Subroutine.*redefined/
            or $w =~ /Some Apache2 modules failed to load/
            or push @warn, "$file: $w";
        return; # somehow this supresses warnings under make test
    };

    ok ( eval{ require $file }, "$file loaded" )
        or diag "Error in $file: $@";
};

# print report
foreach (@warn) {
    diag "WARN: $_";
};

# If you are concerned about cover -t, then probably warnings during load
# are not OK with you
is( scalar @warn, 0, "No warnings during load (except redefined)" );

done_testing;
