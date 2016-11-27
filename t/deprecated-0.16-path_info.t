#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf;

my @warn;
$SIG{__WARN__} = sub {
    my $w = shift;
    $w =~ /DEPRECATED/ or die 'Unexpected: '.$w;
    push @warn, $w;
};

MVC::Neaf->route( '/' => sub {
    my $req = shift;

    return { -content => $req->path_info };
} );

my $data = MVC::Neaf->run->( { REQUEST_URI => "/something" } );

is ($data->[2][0], "something", "path_info round trip" );
is (scalar @warn, 1, "1 warn issued" );
like ($warn[0], qr/path_info/, "path_info in warn");
like ($warn[0], qr/path_info_regex/, "path_info_regex in warn");
note $_ for @warn;

done_testing;
