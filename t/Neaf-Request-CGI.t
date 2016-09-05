#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf;
# Must autoload Request::CGI - so don't use explicitly!

my $capture_req;
my $capture_stdout;
MVC::Neaf->route( "/my/script" => sub {
    $capture_req = shift; # "my" omitted on purpose
    return {
        -content => $capture_req->param( foo => '\w+' => '<undef>' ),
    }
} );

is ($MVC::Neaf::Request::CGI::VERSION, undef, "Module NOT loaded yet");

{
    local $ENV{HTTP_HOST};
    local @ARGV = qw( /my/script?foo=42 );
    local *STDOUT;
    open STDOUT, ">", \$capture_stdout;

    MVC::Neaf->run;
    1;
};

note $capture_stdout;

like ($MVC::Neaf::Request::CGI::VERSION, qr/\d+\.\d+/, "Module auto-loaded")
    or die "Nothing to test here, bailing out";

like ($capture_stdout, qr/\n\n42$/s, "Reply as expected");
like ($capture_stdout, qr#Content-Type: text/plain; charset=utf-8#
    , "content type ok");

is ($capture_req->http_version, "1.0", "http 1.0 autodetected");

done_testing;
