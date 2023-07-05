#!/usr/bin/env perl

=head1 DESCRIPTION

Test that absolute/relative path handling works.

=cut

use strict;
use warnings;
use Test::More;

use MVC::Neaf::X;

my $obj = MVC::Neaf::X->new( neaf_base_dir => '/www/mysite' );

is $obj->dir( 'foo' ), '/www/mysite/foo', 'relative path extended';
is $obj->dir( '/www/images' ), '/www/images', 'absolute path untouched';
is_deeply
    $obj->dir( [ 'foo', '/www/images' ] ),
    ['/www/mysite/foo', '/www/images'],
    'ditto with array ref';

done_testing;
