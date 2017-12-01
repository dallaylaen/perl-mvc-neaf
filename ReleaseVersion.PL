#!/usr/bin/env perl

use strict;
use warnings;
use IPC::Open3 qw(open3);
sub fatal($);

my $module = 'lib/MVC/Neaf.pm';
my $cover_wanted = 80;

# This is an automated release helper.
# See CHECKLIST

# CHECK GIT
my $branch = `git rev-parse --abbrev-ref HEAD`;
$branch =~ s/\s+$//s;
$branch eq "master"
    or fatal "On branch '$branch' and not 'master'";

my @extra;
push @extra, map { /(\S+)\s*$/ and $1 } `git diff-index HEAD --`;
push @extra, map { /(\S+)\s*$/ and $1 } `git ls-files --other --directory --exclude-standard`;

@extra = grep { $_ !~ /^[A-Z]+$/ } @extra;
!@extra
    or fatal "Extra/modified files:\n  @extra";

open my $fd, '<', $module
        or die "Failed to open $module: $!";
my $version;
while (<$fd>) {
    /our +\$VERSION *= *(\d+\.\d+);/ or next;
    $version = $1;
    last;
};
close $fd;
fatal("Version not found in $module")
    unless $version;

unlink "MANIFEST";
run_cmd( "perl Makefile.PL" )
    and run_cmd( "make clean >/dev/null" )
    and run_cmd( "perl Makefile.PL" )
    and run_cmd( "make manifest 2>/dev/null" )
    and run_cmd( "rm -rf cover_db" )
    or stop_here();

# CHECK TEST
# TODO perlbrew
run_test();

my $cover = run_cmd("cover -t");
$cover->out =~ /Total.*\s(\d+.\d+)/m or stop_here();

fatal( "Coverage $1 too low, must exceed $cover_wanted" )
    if $1 < $cover_wanted;
fatal( "Coverage failed" )
    unless $cover;

sub run_test {
    my $where_perl = shift;

    $where_perl and local $ENV{PATH} = "$where_perl:$ENV{PATH}";

    my $pid = open3( \*XIN, \*XOUT, \*XERR, "prove -Ilib t xt");
    close XIN;
    my @test_out = <XOUT>;
    my @test_err = <XERR>;
    waitpid( $pid, 0 );
    my $test_ret = $? >> 8;

    @test_err = grep { !/^\s*#/ and /at.*\/lib\// } @test_err;

    fatal "Warnings in test: \n @test_err"
        if @test_err;
    fatal "Tests fail: \n @test_out"
        if $test_ret;
};

sub run_cmd {
    print "# Running command: @_\n";

    my $pid = open3( \*XIN, \*XOUT, \*XERR, @_);
    close XIN;
    my @out = <XOUT>;
    my @err = <XERR>;
    waitpid( $pid, 0 );
    my $ret = $? >> 8;

    print "# exit code $ret\n" if $ret;

    return bless { out => \@out, err => \@err, ret => $ret, cmd=>"@_" }
        , "RESULT";
};

if ($version) {
    my $newver = int ($version * 100 + 1)/100;
    print "VERSION=$newver\n";
};

my $bad;
stop_here() if $bad;
print "# release of $module version recommended\n";
exit;


sub fatal($) {
    my $arg = shift;
    chomp $arg;
    print "FATAL: $arg\n";
    $bad++;
    # exit 1;
};

sub stop_here {
    fatal( shift ) if @_;
    fatal( "Something went wrong" ) unless $bad;

    print "Exit code $bad, release NOT recommended";
    exit $bad;
};

package RESULT;

use overload
    'bool' => sub { !$_[0]->{ret} },
    '""'   => sub { my $x = shift; join '', @{$x->{out}}
        , map {"! $_" }@{$x->{err}} };

sub out {
    return join '', @{ $_[0]->{out} };
};


