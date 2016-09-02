#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use URI::Escape;
use Encode;

use MVC::Neaf::Request;

my $copy = uri_unescape( "%C2%A9" ); # a single (c) symbol

my $req = MVC::Neaf::Request->new(
	path => "/foo/bar",
	all_params => { x => 42 },
	neaf_cookie_in => { cook => $copy },
);

$copy = decode_utf8($copy);

is ($req->path, "/foo/bar", "Path round trip");

is ($req->param( foo => qr/.*/), '', "Empty param - no undef");
$req->set_param( foo => 137 );
is ($req->param( foo => qr/.*/), 137, "set_param round trip" );

$req->set_path( "" );
is ($req->path, "/", "set_path round trip" );
$req->set_path( "//////" );
is ($req->path, "/", "set_path round trip - extra slashes" );

# TODO more thorough unicode testing
is ($req->get_cookie( cook => qr/.*/ ), $copy, "Cookie round-trip");
is ($req->get_cookie( cook => qr/.*/ ), $copy, "Cookie doesn't get double-decoded");

my $form_h = $req->get_form_as_hash( x => '\d+', y => '\d+' );
is_deeply( $form_h, { x => 42 }, "Hash form validation" );

my @form_l = $req->get_form_as_list( '\d+', qw(x y z t) );
is_deeply ( \@form_l, [ 42, undef, undef, undef ], "List form validation" );

@form_l = $req->get_form_as_list( [ '\d+', -1 ], qw(x y z t) );
is_deeply ( \@form_l, [ 42, -1, -1, -1 ], "List form validation w/default" );


done_testing;
