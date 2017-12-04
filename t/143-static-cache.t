#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);

use MVC::Neaf::X::Files;

my ($fd, $file) = tempfile( SUFFIX => '.txt' );

print $fd "Neaf static\n";
close $fd or die "Failed to sync $file: $!";

{
    open my $test, "<", $file
        or die "Can't open file back!";
    local $/;
    is <$test>, "Neaf static\n", "File readable at all";

    close $test;
};

my $st = MVC::Neaf::X::Files->new( root => $file, cache_ttl => 1_000_000 );

my $ret = $st->serve_file( '' );
note explain $ret;

is $ret->{-content}, "Neaf static\n", "Content returned";
is $ret->{-type}, "text/plain", "Content-type detected";

unlink $file or die "Failed to unlink $file: $!";

my $cached = $st->serve_file( '' );
is_deeply $cached, $ret, "File cached - deletion didn't affect it"
    or diag "initial file: ", explain $ret, "cached file: ", explain $cached;

done_testing;


