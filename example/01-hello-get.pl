#!/usr/bin/env perl

use strict;
use warnings;

# always use latest and gratest libraries, not the system ones
use FindBin qw($Bin);
use File::Basename qw(dirname);
use lib dirname($Bin)."/lib";
use MVC::Neaf;
use MVC::Neaf::X::ServerStat;

MVC::Neaf->server_stat( MVC::Neaf::X::ServerStat->new (
	on_write => sub {
		foreach (@{ +shift }) {
			warn "STAT $_->[0] returned $_->[1] in $_->[3] sec\n";
		};
	},
));

my $tpl = <<"TT";
<h1>Hello, [% name %]!</h1>
<form method="GET">
	<input name="name">
	<input type="submit" value="&gt;&gt;">
</form>
TT

MVC::Neaf->route( "/" => sub {
	my $neaf = shift;

	my $name = $neaf->param( name => qr/\w+/, 'Stranger' );
	my $jsonp = $neaf->param( jsonp => qr/.+/ );

	return {
		name => $name,
		-template => \$tpl,
		-view => $jsonp ? 'JS' : 'TT',
		-callback => $jsonp,
	};
});

$SIG{INT} = sub { exit; }; # Civilized shutdown if interrupted

MVC::Neaf->run;

