#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use IPC::Open3;
use LWP::UserAgent;

use FindBin qw($Bin);
use File::Basename qw(dirname);
use lib dirname($Bin)."/lib";

my $root = dirname( $Bin );

my ($example) = glob ("$root/example/01*");
if (!$example or !-f $example) {
	die "No example found in $root/example";
};

# make sure example compiles at all
my $sub = eval { require $example };

if (ref $sub ne 'CODE') {
	die "Failed to load $example: ".($@ || $! || "didn't return returned");
};

# TODO find a free port
my $port = 50000;

# start plack
my $pid = open3( \*SKIP, \*ALSO_SKIP, \*LOG,
	"plackup", "--listen", ":$port", "-I$root/lib", $example );
if (!$pid) {
	plan skip_all => "Plackup didn't start, but $example compiles";
	exit 0;
};
END { kill 9, $pid if $pid }; # TODO check we're still Luke's father

# don't let this test hang!
$SIG{ALRM} = sub {
	die "Script timed out, bailing out";
};
alarm 10;

my $invite = <LOG>;
if (!defined $invite) {
	die "Failed to get any prompt from plackup: $!";
};

my $url = "http://localhost:$port/";

my $agent = LWP::UserAgent->new;

my $resp = $agent->get( $url );
ok ($resp->is_success, "$example returned a 200" );
note $resp->decoded_content;

# avoid warnings
close (SKIP);
close (ALSO_SKIP);

done_testing; # plack will be killed anyway


