#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

use MVC::Neaf;

subtest "with magic" => sub {
    my $app = MVC::Neaf->new;
    my $psgi = $app->run;
    my @known = sort keys %{ $app->get_routes };
    is_deeply \@known, [ '/js/foobar' ], "route loaded via resources"
        or diag "Found routes: @known";

    lives_ok {
        my $nonvoid = $app->run;
    } "reload doesn't die";
};

subtest "without magic" => sub {
    my $app = MVC::Neaf->new->magic(0);
    my $psgi = $app->run;
    my @known = sort keys %{ $app->get_routes };
    is_deeply \@known, [ ], "routes NOT loaded via resources"
        or diag "Found routes: @known";
};

done_testing;

__END__

@@ /js/foobar
let foo = "bar";
