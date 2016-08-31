#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::Request;

my $req = MVC::Neaf::Request->new(
	path => "/foo/bar",
	all_params => { x => 42 },
	neaf_cookies_in => { },
);

is ($req->path, "/foo/bar", "Path round trip");

is ($req->param( foo => qr/.*/), '', "Empty param - no undef");
$req->set_param( foo => 137 );
is ($req->param( foo => qr/.*/), 137, "set_param round trip" );

$req->set_path( "" );
is ($req->path, "/", "set_path round trip" );
$req->set_path( "//////" );
is ($req->path, "/", "set_path round trip - extra slashes" );

done_testing;
