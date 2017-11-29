#!/usr/bin/env perl

use strict;
use warnings;
use MVC::Neaf qw(:sugar);

my $tpl = <<"HTML";
<html>
<head>
    <title>[% title | html %] - [% file | html %]</title>
</head>
<body>
<h1>[% title | html %]</h1>
<script lang="javascript">
"use strict";
var post_to = "/11/js";

function upd() {
    document.getElementById("content").innerHTML = "Waiting for response...";
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if (xhr.readyState != XMLHttpRequest.DONE)
            return;
        // pretend we forgot to check for http status
        document.getElementById("content").innerHTML = xhr.responseText;
    };
    xhr.open( "get", post_to, true );
    xhr.send();
    return false;
};
</script>
<div id="content">Not ready yet...</div>
<input type="submit" value="Get data!" onClick="return upd()">

<div>Don't forget to look at the server logs if you see anything unusual.</div>
</body>
</html>
HTML

get '/11/oops' => sub {
    my $req = shift;
    return {
        file  => 'example/11 NEAF '.MVC::Neaf->VERSION,
        title => 'Traceable error response',
    };
}, -template => \$tpl, -view => 'TT', description => "Unexpected error demo";

get + post '/11/js' => sub {
    die "Foobared";
};

neaf->run;
