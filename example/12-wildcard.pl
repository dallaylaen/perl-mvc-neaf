#!/usr/bin/env perl

use strict;
use warnings;

use MVC::Neaf qw(:sugar);

my $tpl = <<'HTML';
<html>
<head>
    <title>[% title | html %] - [% file | html %]</title>
    <style>
        .error {
            border: red solid 1px;
        }
    </style>
</head>
<body>
    <h1>[% title | html %]</h1>
    [% IF is_valid %]
        <h1>Guests welcome!</h2>
    [% END %]
    <form name="guest" method="POST">
        [% FOREACH item IN guest_list %]
            <div[% IF item.error %] class="error"[% END %]>
                Guest [% item.id %]: <i>name as word(s), arrival as time</i><br>
                <input name="name[% item.id %]" value="[% item.name | html %]">
                <input name="stay[% item.id %]" value="[% item.stay | html %]">
            </div>
        [% END %]
        Add guest [% max_guest %]: <i>name as word(s), arrival as time</i><br>
        <input name="name[% max_guest %]">
        <input name="stay[% max_guest %]">
        <br>
        <input type="submit" value="Submit guests">
    </form>
</body>
HTML

neaf form => guest => [ [ 'name\d+' => '\w+( +\w+)*' ], [ 'stay\d+' => '\d+:\d+' ] ],
    engine => 'Wildcard';

get+post '/12/wildcard' => sub {
    my $req = shift;

    my $guest = $req->form("guest");

    my %tuples;
    foreach ($guest->fields) {
        /^(\w+)(\d+)$/ or die "How this even possible?";
        $tuples{$2}{$1} = $guest->raw->{$_};
        $tuples{$2}{error}++ if $guest->error->{$_};
        $tuples{$2}{id} = $2; # redundant, but simplifies processing
    };

    my @list = sort { $a->{id} <=> $b->{id} }
        grep { $_->{name} } values %tuples;

    return {
        guest_list => \@list,
        max_guest  => @list ? ($list[-1]{id} + 1) : 1,
        is_valid   => !grep { $_->{error} } @list,
    };
}, default => {
    -view     => 'TT',
    -template => \$tpl,
     title    => 'Unforeknown form fields',
     file     => 'example/12 NEAF '.neaf->VERSION,
}, description => 'Unforeknown form fields';

neaf->run;

