#!/usr/bin/env perl

use strict;
use warnings;

# always use latest and gratest libraries, not the system ones
use FindBin qw($Bin);
use File::Basename qw(basename dirname);
use lib dirname($Bin)."/lib";
use MVC::Neaf;

# HACK This allows us to run flexibly under different servers,
# until Neaf obtains ability to dynamically configure paths
# (this feature is planned but not yet even designed).
my $scriptname = basename(__FILE__);
$scriptname =~ s/\.neaf$/\.cgi/; # OK, the .neaf was stupid, TODO rename all
my $path = $ENV{EXAMPLE_PATH_REQUEST} || "/cgi/$scriptname";

my $tpl = <<"TT";
<head>
    <title>Http request in a nutshell</title>
    <style>
        span { border: dotted 1px red; }
    </style>
</head>
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
} );

MVC::Neaf->run;
