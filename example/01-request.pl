#!/usr/bin/env perl

use strict;
use warnings;

# always use latest and greatest libraries, not the system ones
use FindBin qw($Bin);
use File::Basename qw(basename dirname);
use lib dirname($Bin)."/lib";
use MVC::Neaf;

my $script = basename(__FILE__);
my $path   = "/cgi/$script";
my $descr  = "HTTP request in a nutshell";

my $tt_head = <<"TT";
<html><head><title>$descr - $script</title></head>
<body><h1>$script</h1><h2>$descr</h2>
TT

my $tpl = <<"TT";
$tt_head
    <style>
        span { border: dotted 1px red; }
    </style>
<b>Hover over dotted rectangles to see the function returning this part.</b>
<br><br>

Client ip: <span title="client_ip">[% client_ip %]</span>
<br><br>
<span title="method">[% method %]</span>
<span title="path">[% path %]</span>
HTTP/<span title="http_version">[% http_version %]</span>
<br>
Host: <span title="hostname">[% hostname %]</span>
<br><br>
<span title="scheme">[% scheme %]</span>://
<span title="hostname">[% hostname %]</span>:
<span title="port">[% port %]</span>
<span title="script_name">[% script_name %]</span>
<span title="path_info">[% path_info %]</span>
<br><br>
[% IF error.size %]
<h1>Error list</h1>
[% FOREACH e IN error %]
[% e %]<br>
[% END %]
[% END %]
TT

MVC::Neaf->route( $path => sub {
    my $req = shift;

    $req->redirect( "$path/and/beyond" )
        unless $req->path_info;

    my @error;
    local $SIG{__DIE__} = sub { push @error, shift };
    return {
        -template => \$tpl,
        error => \@error,
        map {
            $_ => eval { $req->$_ } || "unimplemented: $_";
        } qw(method path http_version scheme hostname port
            script_name path_info client_ip ),
    };
}, description => $descr );

MVC::Neaf->run;
