#!/usr/bin/env perl

use strict;
use warnings;
use Carp;

# always use latest and gratest libraries, not the system ones
use FindBin qw($Bin);
use File::Basename qw(dirname);
use lib dirname($Bin)."/lib";
use MVC::Neaf;
$SIG{__WARN__} = \&Carp::cluck;

my $tpl = <<"TT";
<html>
<head>
    <title>[% title %]</title>
</head>
<body>
<h1>[% IF name %]Hello, [% name %]![% ELSE %]What's your name?[% END %]</h1>
<form method="POST" action="/forms/02-post.cgi">
    Change name: <input name="name"/><input type="submit" value="&gt;&gt;"/>
</form>
</body>
</html>
TT

MVC::Neaf->route("/forms/02-post.cgi" => sub {
    my $req = shift;

    my $name = $req->param( name => qr/[-\w ]+/, '' );
    if (length $name) {
        $req->set_cookie( name => $name );
    };

    $req->redirect( $req->referer || "/" );
}, method => "POST");

MVC::Neaf->route("/" => sub {
    my $req = shift;

    my $name = $req->get_cookie( name => qr/[-\w ]+/ );
    return {
        -view => 'TT',
        -template => \$tpl,
        title => 'Hello',
        name => $name,
    };
});

MVC::Neaf->run;

