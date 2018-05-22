#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Warn;

use MVC::Neaf;

warnings_like {
MVC::Neaf->set_path_defaults( "/" => { foo => 42 } );
} [ qr/MVC::Neaf->set_path_defaults.*DEPRECATED/ ], "Deprecated warning";

done_testing;
