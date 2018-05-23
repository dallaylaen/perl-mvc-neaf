#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Warn;
use MVC::Neaf::Util qw(JSON);

use MVC::Neaf;

get '/sess' => sub {
    my $req = shift;

    $req->save_session( { foo => 42 } );
    +{};
};

scalar neaf->run;

warnings_like {
neaf session => 'MVC::Neaf::X::Session::Cookie', key => 'insecure'
    , view_as => 'sess_sess';
} [], "session after run() = ok, but only first time";

scalar neaf->run;

warnings_like {
neaf session => 'MVC::Neaf::X::Session::Cookie', key => 'insecure'
    , view_as => 'sess_sess';
} [ qr#Useless.*set_session_handler# ], "Second try after lock = no go";

my ($code, $head, $content);

($code, $head, $content) = neaf->run_test( '/sess' );
is $code, 200, "Successful request after all";
$content = eval { JSON->new->decode( $content ) };
is $@, '', "No error decoding JSON";
is_deeply $content, { sess_sess => { foo => 42 } }, "Session made it to the render";
like $head->header( "Set-Cookie" ), qr#neaf\.session=#, "Cookie encoded somehow";
note $head->header( "Set-Cookie" );

done_testing;
