#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::View::TT;

my $view = MVC::Neaf::View::TT->new;

eval {
    $view->render({ -template => "foo.html", foo => 42, bar => 137 });
};
like $@, qr/^MVC::Neaf::/, "No foo.html present to begin with";
note $@;

$view = MVC::Neaf::View::TT->new( preload => \*DATA );

my $content = $view->render({ -template => "foo.html", foo => 42, bar => 137 });
is $content, "FOO=42", "Rendered from DATA";

$view = MVC::Neaf::View::TT->new( preload => __FILE__ );
$content = $view->render({ -template => "foo.html", foo => 42, bar => 137 });
is $content, "FOO=42", "Rendered from explicit file name";

done_testing;

__DATA__

garbage

@@ TT foo.html
FOO=[% foo %]

@@ XSLate foo.html
<: Unsupported yet :>

@@ TT bar.html
BAR=[% bar %]


