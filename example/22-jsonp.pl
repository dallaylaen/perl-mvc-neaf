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

# always use latest and greatest Neaf
use FindBin qw($Bin);
use File::Basename qw(dirname basename);
use lib dirname($Bin)."/lib";
use MVC::Neaf;

my $script = basename(__FILE__);

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
<script lang="javascript" src="/cgi/$script/jsonp?callback=foo&delay=1"></script>
</body>
TT

# Main app
MVC::Neaf->route( cgi => $script => sub {
    return {
        -template => \$tpl,
    };
}, description => "Loading data via JSONP callback" );

# callback
MVC::Neaf->route( cgi => $script => jsonp => sub {
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
