#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf::X::ServerStat;

my @data;
my $stat = MVC::Neaf::X::ServerStat->new(
    write_thresh_time => 9**9**9, # never
    write_thresh_count => 2,
    on_write => sub { @data = @{ +shift } },
);

$stat->record_start;
$stat->record_controller( "/foo" );
$stat->record_finish( 200 );
is (scalar @data, 0, "1 done - data empty" );

# note explain $stat;

$stat->record_start;
$stat->record_controller( "/bar" );
$stat->record_finish( 500 );
is (scalar @data, 2, "2 done - data arrives" );

note explain \@data;

is ($data[0][1], 200, "status retained");
is ($data[1][0], "/bar", "location retained");

is (scalar @{ $data[0] }, 5, "5 elements");
is (scalar @{ $data[1] }, 5, "5 elements (2)");

done_testing;
