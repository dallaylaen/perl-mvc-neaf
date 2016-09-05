#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf;

# first, prepare some test subs
MVC::Neaf->route( foo => sub {
    my $req = shift;

    my $bar = $req->param( "bar" ); # this dies

    return {
        -content => "Got me wrong",
    };
});

MVC::Neaf->route( bar => sub {
    my $req = shift;

    my $bar = $req->param( bar => qr/.*/ );

    return {
        -template => \"[% content %]",
        content => $bar,
    };
});

my $code = MVC::Neaf->run;

is (ref $code, 'CODE', "run returns sub in scalar context");

my %request = (
    REQUEST_METHOD => 'GET',
    REQUEST_URI => "/",
    QUERY_STRING => "bar=137",
    SERVER_PROTOCOL => "HTTP/1.0",
);

my $root = $code->( \%request ); # not found
note explain $root;
is (scalar @$root, 3, "PSGI-compatible");
is ($root->[0], 404, "Root not found");

$request{REQUEST_URI} = "/foo";
my $foo = $code->( \%request );
note explain $foo;
is (scalar @$foo, 3, "PSGI-compatible");
is ($foo->[0], 500, "Failed request");

$request{REQUEST_URI} = "/bar";
my $bar = $code->( \%request );
note explain $bar;
is (scalar @$bar, 3, "PSGI-compatible");
is ($bar->[0], 200, "Normal request");
is_deeply ($bar->[2], [137], "Content is fine");

done_testing;
