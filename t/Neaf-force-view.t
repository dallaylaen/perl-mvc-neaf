#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf;
MVC::Neaf->set_forced_view("Dumper");

is( ref MVC::Neaf->load_view("TT"), "MVC::Neaf::View::Dumper", "force view");
is( ref MVC::Neaf->load_view("Custom"), "MVC::Neaf::View::Dumper", "force view 2");

is_deeply( [MVC::Neaf->load_view("JS")->render({-template=>"Foo"})]
    , [ "\$VAR1 = {\n  '-template' => 'Foo'\n};\n", "text/plain"]
    , "View actually works");

done_testing;
