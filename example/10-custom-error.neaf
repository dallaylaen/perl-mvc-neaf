#!/usr/bin/env perl

use strict;
use warnings;

# always use latest and gratest libraries, not the system ones
use FindBin qw($Bin);
use File::Basename qw(dirname);
use lib dirname($Bin)."/lib";
use MVC::Neaf;

MVC::Neaf->error_template( 404 => {
	-template => \"<h1>You are searching in the wrong place.</h1>",
} );

MVC::Neaf->run;
