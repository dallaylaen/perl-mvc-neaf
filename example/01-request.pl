#!/usr/bin/env perl

use strict;
use warnings;

# This script demonstrates...
my $descr  = "HTTP request in a nutshell";

# Always use latest and greatest Neaf, no matter what's in the @INC
use FindBin qw($Bin);
use File::Basename qw(basename dirname);
use lib dirname($Bin)."/lib";
use MVC::Neaf;
use MVC::Neaf::X::ServerStat;

# Some request timing statistics
my ($count, $total_C, $total) = (0,0,0,0);
my $want_stat = !$ENV{NEAF_NOSTAT};
$want_stat and MVC::Neaf->server_stat( MVC::Neaf::X::ServerStat->new (
    on_write => sub {
        foreach (@{ +shift }) {
            $count++;
            $total_C += $_->[2];
            $total   += $_->[3];
            warn "STAT $_->[0] returned $_->[1] in $_->[3] sec\n";
        };
    },
));
END {
    if ($want_stat) {
        undef $MVC::Neaf::Inst; # make sure stat object is DESTROYED
        warn ".\n.\n"; # get rid of the stupid ^C
        warn "$count pages served.\n";
        warn "$total_C s spent in controller, "
            .($total-$total_C)." s spent in view.\n";
    };
};
$SIG{INT} = sub { exit }; # civilized exit if Ctrl-C

# Add some flexibility to run alongside other examples
my $script = basename(__FILE__);

# And some HTML boilerplate.
my $tt_head = <<"TT";
<html><head><title>$descr - $script</title></head>
<body><h1>$script</h1><h2>$descr</h2>
TT

# The boilerplate ends here

my $tpl = <<"TT";
$tt_head
    <style>
        span { border: dotted 1px red; }
    </style>
<b>Hover over dotted rectangles to see the function returning this part.</b>
<br><br>

Client ip: <span title="client_ip">[% client_ip %]</span><br>
You claim to come from <span title="referer">[% referer %]</span>
using <span title="user_agent">[% user_agent %]</span>,
but I don't trust you.
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

MVC::Neaf->route( cgi => $script => sub {
    my $req = shift;

    $req->redirect( "/cgi/$script/and/beyond" )
        unless $req->path_info;

    my @error;
    local $SIG{__DIE__} = sub { push @error, shift };
    return {
        -template => \$tpl,
        error => \@error,
        map {
            $_ => eval { $req->$_ } || "unimplemented: $_";
        } qw(method path http_version scheme hostname port
            script_name path_info client_ip referer user_agent),
    };
}, description => $descr );

MVC::Neaf->run;
