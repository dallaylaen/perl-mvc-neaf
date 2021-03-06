#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Fcntl qw(:flock);

use MVC::Neaf::X::Session::File;

eval {
    MVC::Neaf::X::Session::File->new;
};
like ($@, qr/dir/, "no dir = no go");

my $temp = tempdir( CLEANUP => 1 );

# test flock just in case tests are being run on NFS
my $testfile = "$temp/lock-test";
open my $fd, "+>", $testfile
    or die "Failed ot open (rw) $testfile: $!";
if (!flock $fd, LOCK_SH) {
    plan skip_all => "File lock unavailable at $temp, skipping test: $!";
    exit;
};
close $fd;
unlink $testfile;

# Now real testing begins
my $sess = MVC::Neaf::X::Session::File->new( dir => $temp, session_ttl => 600 );

my $w = $sess->save_session( 'foo/../bar' => { bar => 42 } );
is ($w->{id}, 'foo/../bar', "save: id round trip" );
cmp_ok( $w->{expire}, ">", time, "Expires in the future" );

is_deeply( $sess->load_session( "foo" ), undef, "No such session ok" );
my $r = $sess->load_session( "foo/../bar" );

is_deeply( $r->{data}, { bar => 42 }, "Session data round trip" );

my $sess_un = MVC::Neaf::X::Session::File->new( dir => $temp
    , session_ttl => -100 );

$sess_un->save_session( foo => { bar => 42 } );
is_deeply( $sess_un->load_session( "foo" ), undef, "ttl < 0 - expired" );

done_testing;
