#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::Request;

my $req = MVC::Neaf::Request->new(
    cached_params => { x => 42 },
);

my @warn;
local $SIG{__WARN__} = sub {
    $_[0] =~ /DEPRECATED/ or die $_[0];
    push @warn, shift;
};

my $form_h = $req->get_form_as_hash( x => '\d+', y => '\d+' );
is_deeply( $form_h, { x => 42 }, "Hash form validation" );

my @form_l = $req->get_form_as_list( '\d+', qw(x y z t) );
is_deeply ( \@form_l, [ 42, undef, undef, undef ], "List form validation" );

@form_l = $req->get_form_as_list( [ '\d+', -1 ], qw(x y z t) );
is_deeply ( \@form_l, [ 42, -1, -1, -1 ], "List form validation w/default" );

is scalar @warn, 3, "3 warns issued";
note "WARN: $_" for @warn;

done_testing;
