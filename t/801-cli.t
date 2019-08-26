#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use MVC::Neaf;
use MVC::Neaf::CLI;

my $warn = 0;
$SIG{__WARN__} = sub { $warn++; warn $_[0]; };

my $app = MVC::Neaf->new;

$app->route( foo => sub { +{}} );
$app->route( bar => sub { +{}} );
neaf->route( noexist => sub { +{} } ); # this should NOT affect the new() routes

subtest '--list' => sub {
    my $app_list = capture( $app, qw( --list ) );

    like ($app_list, qr(^\[.*GET.*/bar.*\n\[.*GET.*/foo.*\n$)s, "--list works");
    unlike $app_list, qr(noexist), "No mentions of parallel reality routes";
    note $app_list;
};

# 1st app has its routes already locked
# And we cannot reinitialise (yet)
my $app2 = MVC::Neaf->new;
$app2->add_route( quux => sub { +{} } );

subtest 'forced view' => sub {
    my $force_view = capture( $app2, qw(--view Dumper /quux) );

    like ($force_view, qr/\n\n\$VAR1\s*=\s*\{.*\};?$/s, "force view worked");
    note $force_view;

    ok !$warn, "$warn of 0 warnings issued";
};

subtest '--help' => sub {
    my $summary = capture( $app, qw( --help ) );
    like $summary, qr/--help\b/,   'help mentioned';
    like $summary, qr/--listen\b/, 'server mentioned';
    like $summary, qr/--list\b/,   'list mentioned';
    like $summary, qr/MVC::Neaf/,  'Neaf itself mentioned';
    note $summary;
};

done_testing;

sub capture {
    my $app = shift;
    local @ARGV = @_;

    my $out = '';
    local *STDOUT;
    open (STDOUT, ">", \$out) or die "Failed to redirect STDOUT";

    $app->run;
    return $out;
};
