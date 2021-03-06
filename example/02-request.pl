#!/usr/bin/env perl

# This script demonstrates various getters of the Request object
#    of Not Even A Framework

use strict;
use warnings;

use MVC::Neaf;

# Now to the NEAF itself: set common default values
neaf view => 'TT02' => 'TT';
neaf default =>
    { -view => 'TT02', file => 'example/02 NEAF '.MVC::Neaf->VERSION },
    path => '/02';

# So far we have to specify \*DATA manually, no magic yet
neaf->load_resources( \*DATA );

# Sic!
get+post '/02/request' => sub {
    my $req = shift;

    if (!$req->postfix) {
        # This actually dies but with a special-case exception
        # that Neaf converts into a proper redirect
        $req->redirect( $req->prefix . "/and/beyond" );
    };

    # Just return the data
    # Override the -view if user wants it
    return {
        title     => 'Taking apart the request object',
        header_in => $req->header_in->as_string,
        -view     => $req->param(as_json => '1') ? 'JS' : 'TT02',
        map { $_  => $req->$_ }
            qw( scheme hostname port method http_version
            path prefix postfix
            referer user_agent client_ip ),
    };
}, (
    # This may also be written as 'default => { -template => ... }'
    # generating an overridable default value for this controller only
    -template       => "main.html",
    # This is a nerdy cousin of /02/request/:param_name
    #     - smarter, but less pretty
    path_info_regex => '.*',
    # This line is just for information
    # see perl <this file> --list
    description     => 'Taking apart the request object',
);

# Do good things... and RUN!!!
neaf->run;

__DATA__
@@ main.html view=TT02
<head>
    <title>[% title | html %] - [% file | html %]</title>
    <style>
        .method {
            border: dotted red 1px;
            margin: 1px;
            padding: 1px;
        }
    </style>
</head>
<body>
    <h1>[% title | html %]</h1>
    <h2>The request</h2>
    <div><i>Hover over dotted elements to see the relevant method</i></div>
    <div>
    <span class="method" title="scheme">[% scheme | html %]</span>
    ://
    <span class="method" title="hostname">[% hostname | html %]</span>
    :
    <span class="method" title="port">[% port | html %]</span>
    <span class="method" title="prefix">[% prefix | html %]</span>
    /
    <span class="method" title="postfix">[% postfix | html %]</span>

    </div>
    <h2>Repeat</h2>
    <ul>
        <li><a href="[% path | html %]">As GET request</a></li>
        <li><a href="[% path | html %]?as_json=1">As plain JSON</a></li>
        <li><form method="POST"><input type="submit" value="As POST request"></li>
    </ul>
    <h2>How web-server saw it</h2>
    <tt>
    <span class="method" title="method">[% method | html %]</span>
    <span class="method" title="path">[% path | html %]</span>
    HTTP/<span class="method" title="http_version">[% http_version | html %]</span>
    <br>
    <pre class="method" title="header_in-&gt;as_string">[% header_in | html %]</pre>
    </tt>
    <h2>The client</h2>
    IP:
    <span class="method" title="client_ip">[% client_ip | html %]</span>
    <br>
    Referer:
    <span class="method" title="referer">[% referer | html %]</span>
    <br>
    User-agent:
    <span class="method" title="user_agent">[% user_agent | html %]</span>
    <br>

</body>
</html>
