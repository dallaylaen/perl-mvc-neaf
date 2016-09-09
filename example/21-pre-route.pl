#!/usr/bin/env perl

use strict;
use warnings;

# always use latest and gratest libraries, not the system ones
use FindBin qw($Bin);
use File::Basename qw(dirname);
use lib dirname($Bin)."/lib";
use MVC::Neaf;

my %message = (
    en => "Dear friends",
    de => "Liebe Freunde",
    fr => "Chers amis",
);

my $tpl = <<"TT";
<h1>[% message %]</h1>
[% FOREACH lang IN menu %]
<a href="/[% lang %]/cgi/05-lang.cgi">[% lang %]</a>
[% END %]
TT

MVC::Neaf->pre_route( sub {
    my $req = shift;

    my $path = $req->path;

    if ($path =~ s#^/([a-z][a-z])/#/#) {
        $req->set_param( lang => $1 );
        $req->set_full_path($path);
    };
});

MVC::Neaf->route("/" => sub {
    my $req = shift;

    my $lang = $req->param( lang => qr/[a-z][a-z]/, 'en' );

    return {
        -template => \$tpl,
        message => ($message{$lang} || die 404),
        menu => [ sort keys %message ],
    };
});

MVC::Neaf->run;
