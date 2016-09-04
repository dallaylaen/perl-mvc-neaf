#!/usr/bin/env perl

use strict;
use warnings;

# always use latest and gratest libraries, not the system ones
use FindBin qw($Bin);
use File::Basename qw(dirname);
use lib dirname($Bin)."/lib";
use MVC::Neaf;

MVC::Neaf->route( "/" => sub {
    return {
        -template => \"[% IF %]", # this dies
    };
});

MVC::Neaf->run;
