#!/usr/bin/env perl

use strict;
use warnings;

# This script demonstrates...
my $descr  = "HTTP Get request - fetch parameters";

# Always use latest and greatest Neaf, no matter what's in the @INC
use FindBin qw($Bin);
use File::Basename qw(basename dirname);
use lib dirname($Bin)."/lib";
use MVC::Neaf;
use MVC::Neaf::X::ServerStat;

# Add some flexibility to run alongside other examples
my $script = basename(__FILE__);

# And some HTML boilerplate.
my $tt_head = <<"TT";
<html><head><title>$descr - $script</title></head>
<body><h1>$script</h1><h2>$descr</h2>
TT

# The boilerplate ends here

MVC::Neaf->server_stat( MVC::Neaf::X::ServerStat->new (
    on_write => sub {
        foreach (@{ +shift }) {
            warn "STAT $_->[0] returned $_->[1] in $_->[3] sec\n";
        };
    },
));

my $tpl = <<"TT";
$tt_head
<h3>Hello, [% name %]!</h3>
<form method="GET">
    <input name="name">
    <input type="submit" value="&gt;&gt;">
</form>
TT

MVC::Neaf->route( cgi => $script => sub {
    my $neaf = shift;

    my $name = $neaf->param( name => qr/\w+/, 'Stranger' );
    my $jsonp = $neaf->param( jsonp => qr/.+/ );

    return {
        name => $name,
        -template => \$tpl,
        -view => $jsonp ? 'JS' : 'TT',
        -jsonp => $jsonp,
    };
}, description => $descr);

$SIG{INT} = sub { exit; }; # Civilized shutdown if interrupted

MVC::Neaf->run;

