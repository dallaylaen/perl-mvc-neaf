#!/usr/bin/env perl

use strict;
use warnings;

# Always use the latest and greatest Neaf
use FindBin qw($Bin);
use File::Basename qw(dirname basename);
use lib dirname($Bin)."/lib";
use MVC::Neaf;

my $err_tpl = <<"TT";
<html><head><title>Error [% error %] - demo</title></head>
<body><h1>You are searchin in the wrong place</h1>
<h2>Propagated in [% caller.1 %]</h2>
<a href="/">Back...</a>
TT

MVC::Neaf->error_template( 405 => {
    -template => \$err_tpl,
} );

MVC::Neaf->route( cgi => basename(__FILE__) => sub {} => method => []
    => description => "Demonstrate custom error template" );

MVC::Neaf->run;
