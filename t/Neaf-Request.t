#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use URI::Escape;
use Encode;

use MVC::Neaf::Request;

my $copy = uri_unescape( "%C2%A9" ); # a single (c) symbol
$copy = decode_utf8($copy);

my $req = MVC::Neaf::Request->new(
    cached_params => { x => 42 },
    header_in => HTTP::Headers->new(
        Cookie => 'cook=%C2%A9; guy=bad',
        Referer => 'http://google.com',
        User_Agent => 'test bot',
    ),
);
$req->set_full_path("/foo/bar");

is ($req->path, "/foo/bar", "Path round trip");

$req->set_path_info( "woo" );
is ($req->path_info( ), "woo", "path info round trip" );
is ($req->path, "/foo/bar/woo", "Path also modified" );
$req->set_path_info;
is ($req->path, "/foo/bar", "Path reset to where it was");

is ($req->param( foo => qr/.*/), undef, "Empty param - undef");
$req->set_param( foo => 137 );
is ($req->param( foo => qr/.*/), 137, "set_param round trip" );
is ($req->param( foo => '1|7' ), undef, "^foo|bar\$ forbids partial match" );

is ($req->referer, "http://google.com", "referer works");
is ($req->user_agent, "test bot", "user_agent works");

$req->set_full_path( "" );
is ($req->path, "/", "set_path round trip" );

# TODO more thorough unicode testing
is ($req->get_cookie( cook => qr/.*/ ), $copy, "Cookie round-trip");
is ($req->get_cookie( cook => qr/.*/ ), $copy, "Cookie doesn't get double-decoded");
is ($req->get_cookie( guy => qr/\w+/ ), "bad", "Secone cookie ok");

my $form_h = $req->get_form_as_hash( x => '\d+', y => '\d+' );
is_deeply( $form_h, { x => 42 }, "Hash form validation" );

my @form_l = $req->get_form_as_list( '\d+', qw(x y z t) );
is_deeply ( \@form_l, [ 42, undef, undef, undef ], "List form validation" );

@form_l = $req->get_form_as_list( [ '\d+', -1 ], qw(x y z t) );
is_deeply ( \@form_l, [ 42, -1, -1, -1 ], "List form validation w/default" );

eval {
    $req->redirect("https://spacex.com");
};
is (ref $@, "MVC::Neaf::Exception", "Redirect throws an MVC::Neaf::Exception" );
like ($@, qr/^MVC::Neaf/, "Exception tells who it is");
like ($@, qr/spacex.com/, "Exception tells where to the redirect is when str" );
eval {
    $req->error(404);
};
is (ref $@, "MVC::Neaf::Exception", "Erro throws an MVC::Neaf::Exception" );
like ($@, qr/^MVC::Neaf/, "Exception tells who it is");

# Check postpone() callback by flagging an outer flag.
# We'll also check that default do_close() method doesn't die
# because it shouldn't
my $flag = 0;
$req->postpone( sub { $_[0]->close; $flag++ } );
is ($flag, 0, "postpone(): no immediate effect");

is_deeply( [sort $req->header_in_keys], [sort qw[Referer User-Agent Cookie]]
    , "header_in_keys (who needs it anyway?)" );

my $dump = $req->dump;
is( ref $dump, 'HASH', "Dump works");
note explain $dump;

# Now run postponed callback
undef $req;
is ($flag, 1, "postpone(): executed in destroy (and close didn't die)");

done_testing;
