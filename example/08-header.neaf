#!/usr/bin/env perl

use strict;
use warnings;

# always use latest and gratest libraries, not the system ones
use FindBin qw($Bin);
use File::Basename qw(dirname);
use lib dirname($Bin)."/lib";
use MVC::Neaf;

MVC::Neaf->route( "/" => sub {
	my $req = shift;

	return {
		-type => "text/plain",
		-content => join( ";", $req->header_in_keys ). "\n\n"
			. $req->header_in->as_string,
	};
} );

MVC::Neaf->run;
