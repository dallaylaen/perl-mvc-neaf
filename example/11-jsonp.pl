#!/usr/bin/env perl

use strict;
use warnings;

##############################################
# JSONP example.                             #
# It loads javascript structure via callback #
# Some shoddy javascript inside,             #
# patches wanted :)                          #
# Just don't make me carry around JQuery,    #
# this package already has too many deps     #
##############################################

# always use latest and gratest libraries, not the system ones
use FindBin qw($Bin);
use File::Basename qw(dirname);
use lib dirname($Bin)."/lib";
use MVC::Neaf;

my $tpl = <<"TT";
<html>
<head>
    <title>JSONP callback example</title>
<script lang="javascript">
    function foo(data) {
        console.log(data);
        if (data["greeting"]) {
            document.getElementById("container").innerHTML = "<b>"+data["greeting"]+"</b>";
        };
    };
</script>
</head>
<body>
<h1>JSON example</h1>
<div id="container">Not loaded...</div>
<script lang="javascript" src="/forms/11/jsonp?callback=foo&delay=1"></script>
</body>
TT

# Main app
MVC::Neaf->route("/" => sub {
    return {
        -template => \$tpl,
    };
});

# callback
MVC::Neaf->route( forms => 11 => jsonp => sub {
    my $req = shift;

    # This is ugly, but it makes loading process look
    # more natural
    sleep $req->param( delay => '\d+', 0 );

    return {
        -view => 'JS',
        -jsonp => $req->param(callback => '.*'),
        greeting => "Yes, JSONP works",
    };
});

MVC::Neaf->run;
